using System.Text;
using System.Text.Json;
using GodotDotnetMcp.CentralServer;
using static ContractAssertions;
using static ContractPayloadSupport;

internal static class Program
{
    private static async Task<int> Main()
    {
        Console.OutputEncoding = Encoding.UTF8;

        var testCases = new (string Name, Func<Task> Execute)[]
        {
            ("tool_catalog_exposes_workspace_system_dotnet", VerifyToolCatalogAsync),
            ("editor_process_service_supports_injected_external_probe", VerifyInjectedExternalProbeContractAsync),
            ("workspace_project_remove_clears_active_context", VerifyProjectRemoveClearsActiveContextAsync),
            ("system_project_state_returns_editor_required_when_auto_launch_disabled", VerifyEditorRequiredContractAsync),
            ("workspace_project_open_editor_returns_missing_executable_guidance", VerifyMissingExecutableContractAsync),
            ("workspace_project_close_editor_reports_editor_lifecycle_unsupported", VerifyLifecycleUnsupportedContractAsync),
            ("workspace_project_close_editor_force_reports_editor_force_unavailable", VerifyForceUnavailableContractAsync),
            ("workspace_project_restart_editor_reattaches_when_lifecycle_available", VerifyLifecycleRestartContractAsync),
            ("workspace_project_restart_editor_reports_attach_timeout_when_reattach_missing", VerifyLifecycleRestartAttachTimeoutContractAsync),
            ("workspace_project_close_editor_succeeds_when_lifecycle_available", VerifyLifecycleCloseContractAsync),
        };

        var results = new List<object>();
        var success = true;
        foreach (var testCase in testCases)
        {
            try
            {
                await testCase.Execute();
                results.Add(new { name = testCase.Name, success = true });
            }
            catch (Exception ex)
            {
                success = false;
                results.Add(new { name = testCase.Name, success = false, error = ex.Message });
            }
        }

        var summary = new
        {
            success,
            total = testCases.Length,
            passed = results.Count(result => JsonSerializer.SerializeToElement(result).GetProperty("success").GetBoolean()),
            results,
        };

        Console.WriteLine(JsonSerializer.Serialize(summary, new JsonSerializerOptions { WriteIndented = true }));
        return success ? 0 : 1;
    }

    private static Task VerifyToolCatalogAsync()
    {
        var toolCatalog = SerializeToElement(CentralToolCatalog.GetTools());
        var toolNames = toolCatalog.EnumerateArray()
            .Select(element => element.GetProperty("name").GetString() ?? string.Empty)
            .Where(name => !string.IsNullOrWhiteSpace(name))
            .ToArray();

        AssertContains(toolNames, "workspace_project_list");
        AssertContains(toolNames, "system_project_state");
        AssertContains(toolNames, "dotnet_build");
        var removedProxyToolName = string.Concat("workspace_editor_", "proxy_call");
        if (toolNames.Contains(removedProxyToolName, StringComparer.Ordinal))
        {
            throw new InvalidOperationException($"{removedProxyToolName} should not remain in the central tool catalog.");
        }

        var workspaceCount = toolNames.Count(name => name.StartsWith("workspace_", StringComparison.Ordinal));
        var systemCount = toolNames.Count(name => name.StartsWith("system_", StringComparison.Ordinal));
        var bridgeCount = toolNames.Count(name =>
            name.StartsWith("dotnet_", StringComparison.Ordinal)
            || name.StartsWith("cs_", StringComparison.Ordinal)
            || name.StartsWith("solution_", StringComparison.Ordinal));

        if (workspaceCount < 10 || systemCount < 10 || bridgeCount < 5)
        {
            throw new InvalidOperationException($"Unexpected tool catalog composition. workspace={workspaceCount}, system={systemCount}, bridge={bridgeCount}.");
        }

        return Task.CompletedTask;
    }

    private static async Task VerifyInjectedExternalProbeContractAsync()
    {
        await using var harness = ContractHarness.Create("external_probe_injection");
        var projectId = await harness.RegisterProjectAsync();
        var normalizedProjectRoot = Path.GetFullPath(harness.ProjectRoot)
            .TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        var processService = new EditorProcessService(
            new EditorResidencyStore(),
            new FakeExternalEditorProcessProbe(
                new ExternalEditorProcessInfo(
                    4242,
                    normalizedProjectRoot,
                    @"C:\Godot\Godot.exe",
                    $@"Godot_v4.exe --editor --path ""{normalizedProjectRoot}""")));

        var status = processService.FindUntrackedEditorStatus(projectId, harness.ProjectRoot)
            ?? throw new InvalidOperationException("Expected injected external probe to surface an untracked editor status.");

        if (!string.Equals(status.Ownership, "external_untracked", StringComparison.Ordinal))
        {
            throw new InvalidOperationException($"Expected ownership=external_untracked but got {status.Ownership}.");
        }

        if (status.ProcessId != 4242)
        {
            throw new InvalidOperationException($"Expected processId=4242 but got {status.ProcessId}.");
        }
    }

    private static async Task VerifyProjectRemoveClearsActiveContextAsync()
    {
        await using var harness = ContractHarness.Create("remove_clears_active_context");
        var projectId = await harness.RegisterProjectAsync();

        EnsureSuccess(
            await harness.Dispatcher.ExecuteAsync(
                "workspace_project_select",
                SerializeToElement(new { projectId }),
                CancellationToken.None),
            "workspace_project_select");

        await using var mockServer = await harness.AttachMockEditorAsync(
            projectId,
            "contract-remove",
            ["system_project_state"]);
        EnsureSuccess(
            await harness.Dispatcher.ExecuteAsync(
                "system_project_state",
                SerializeToElement(new
                {
                    projectId,
                    autoLaunchEditor = false,
                }),
                CancellationToken.None),
            "system_project_state");

        var removeResponse = await harness.Dispatcher.ExecuteAsync(
            "workspace_project_remove",
            SerializeToElement(new { projectId }),
            CancellationToken.None);
        EnsureSuccess(removeResponse, "workspace_project_remove");

        var payload = SerializeToElement(removeResponse.StructuredContent);
        AssertNestedString(payload, string.Empty, "activeProjectId");
        AssertNestedString(payload, string.Empty, "activeEditorSessionId");
    }

    private static async Task VerifyEditorRequiredContractAsync()
    {
        await using var harness = ContractHarness.Create("editor_required");
        await harness.RegisterProjectAsync();

        var response = await harness.Dispatcher.ExecuteAsync(
            "system_project_state",
            SerializeToElement(new
            {
                projectPath = harness.ProjectRoot,
                autoLaunchEditor = false,
            }),
            CancellationToken.None);

        var payload = EnsureExpectedError(response, "system_project_state", "editor_required");
        AssertNestedString(payload, "editor_required", "centralHostSession", "editorLifecycle", "resolution");
        AssertNestedBoolean(payload, false, "centralHostSession", "autoLaunchAttempted");
    }

    private static async Task VerifyMissingExecutableContractAsync()
    {
        await using var harness = ContractHarness.Create("missing_executable");
        var projectId = await harness.RegisterProjectAsync();

        var response = await harness.Dispatcher.ExecuteAsync(
            "workspace_project_open_editor",
            SerializeToElement(new
            {
                projectId,
                executablePath = Path.Combine(harness.ProjectRoot, "missing", "Godot.exe"),
            }),
            CancellationToken.None);

        var payload = EnsureExpectedError(response, "workspace_project_open_editor", "godot_executable_not_found");
        AssertNestedString(payload, "godot_executable_not_found", "centralHostSession", "editorLifecycle", "resolution");

        var configureWith = payload.GetProperty("guidance").GetProperty("configureWith").EnumerateArray()
            .Select(item => item.GetProperty("tool").GetString() ?? string.Empty)
            .ToArray();
        AssertContains(configureWith, "workspace_project_set_godot_path");
        AssertContains(configureWith, "workspace_godot_set_default_executable");
    }

    private static async Task VerifyLifecycleUnsupportedContractAsync()
    {
        await using var harness = ContractHarness.Create("lifecycle_unsupported");
        var projectId = await harness.RegisterProjectAsync();
        harness.EditorSessions.Attach(BuildMockAttachRequest(projectId, harness.ProjectRoot, "contract-session", ["system_project_state"], 4100));

        var response = await harness.Dispatcher.ExecuteAsync(
            "workspace_project_close_editor",
            SerializeToElement(new
            {
                projectId,
                save = true,
            }),
            CancellationToken.None);

        var payload = EnsureExpectedError(response, "workspace_project_close_editor", "editor_lifecycle_unsupported");
        AssertNestedString(payload, "editor_lifecycle_unsupported", "error");
        AssertNestedBoolean(payload, false, "editorLifecycle", "supportsEditorLifecycle");
    }

    private static async Task VerifyForceUnavailableContractAsync()
    {
        await using var harness = ContractHarness.Create("force_unavailable");
        var projectId = await harness.RegisterProjectAsync();
        harness.EditorSessions.Attach(BuildMockAttachRequest(projectId, harness.ProjectRoot, "contract-force", ["system_project_state"], 4101));

        var response = await harness.Dispatcher.ExecuteAsync(
            "workspace_project_close_editor",
            SerializeToElement(new
            {
                projectId,
                force = true,
            }),
            CancellationToken.None);

        var payload = EnsureExpectedError(response, "workspace_project_close_editor", "editor_force_unavailable");
        AssertNestedString(payload, "editor_force_unavailable", "error");
        AssertNestedBoolean(payload, false, "editorLifecycle", "canForceClose");
    }

    private static async Task VerifyLifecycleRestartContractAsync()
    {
        await using var harness = ContractHarness.Create("lifecycle_restart_success");
        var projectId = await harness.RegisterProjectAsync();
        await using var mockServer = await harness.AttachMockEditorAsync(
            projectId,
            "contract-restart",
            ["system_project_state", EditorSessionService.EditorLifecycleCapability]);

        var response = await harness.Dispatcher.ExecuteAsync(
            "workspace_project_restart_editor",
            SerializeToElement(new
            {
                projectId,
                save = true,
                shutdownTimeoutMs = 5_000,
                attachTimeoutMs = 5_000,
            }),
            CancellationToken.None);
        EnsureSuccess(response, "workspace_project_restart_editor");

        var payload = SerializeToElement(response.StructuredContent);
        AssertNestedString(payload, "contract-restart", "previousEditorSession", "sessionId");
        AssertNestedBoolean(payload, true, "editorLifecycle", "supportsEditorLifecycle");
        AssertContains(mockServer.LifecycleActions, "restart");

        var restartedSessionId = GetNestedString(payload, "editorSession", "sessionId");
        AssertDifferentStrings(restartedSessionId, "contract-restart", "restarted session id");
    }

    private static async Task VerifyLifecycleRestartAttachTimeoutContractAsync()
    {
        await using var harness = ContractHarness.Create("lifecycle_restart_timeout");
        var projectId = await harness.RegisterProjectAsync();
        await using var mockServer = await harness.AttachMockEditorAsync(
            projectId,
            "contract-restart-timeout",
            ["system_project_state", EditorSessionService.EditorLifecycleCapability],
            server => server.ConfigureLifecycleBehavior(restartReattaches: false));

        var response = await harness.Dispatcher.ExecuteAsync(
            "workspace_project_restart_editor",
            SerializeToElement(new
            {
                projectId,
                save = true,
                shutdownTimeoutMs = 1_000,
                attachTimeoutMs = 500,
            }),
            CancellationToken.None);

        var payload = EnsureExpectedError(response, "workspace_project_restart_editor", "editor_restart_attach_timeout");
        AssertNestedString(payload, "editor_restart_attach_timeout", "error");
        AssertContains(mockServer.LifecycleActions, "restart");
    }

    private static async Task VerifyLifecycleCloseContractAsync()
    {
        await using var harness = ContractHarness.Create("lifecycle_close_success");
        var projectId = await harness.RegisterProjectAsync();
        await using var mockServer = await harness.AttachMockEditorAsync(
            projectId,
            "contract-close",
            ["system_project_state", EditorSessionService.EditorLifecycleCapability]);

        var response = await harness.Dispatcher.ExecuteAsync(
            "workspace_project_close_editor",
            SerializeToElement(new
            {
                projectId,
                save = true,
                shutdownTimeoutMs = 5_000,
            }),
            CancellationToken.None);
        EnsureSuccess(response, "workspace_project_close_editor");

        var payload = SerializeToElement(response.StructuredContent);
        AssertNestedBoolean(payload, false, "editorSession", "attached");
        AssertNestedBoolean(payload, false, "editorLifecycle", "resident");
        AssertContains(mockServer.LifecycleActions, "close");
    }

    private sealed class FakeExternalEditorProcessProbe : IExternalEditorProcessProbe
    {
        private readonly IReadOnlyList<ExternalEditorProcessInfo> _processes;

        public FakeExternalEditorProcessProbe(params ExternalEditorProcessInfo[] processes)
        {
            _processes = processes;
        }

        public IEnumerable<ExternalEditorProcessInfo> EnumerateEditorProcesses()
        {
            return _processes;
        }
    }
}
