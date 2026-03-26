using System.Text;
using System.Text.Json;
using GodotDotnetMcp.CentralServer;
using static GodotDotnetMcp.CentralServer.SmokeAssertionSupport;
using static GodotDotnetMcp.CentralServer.SmokePayloadSupport;

internal static class Program
{
    private static async Task<int> Main()
    {
        Console.OutputEncoding = Encoding.UTF8;

        var testCases = new (string Name, Func<Task> Execute)[]
        {
            ("tool_catalog_exposes_workspace_system_dotnet", VerifyToolCatalogAsync),
            ("system_project_state_returns_editor_required_when_auto_launch_disabled", VerifyEditorRequiredContractAsync),
            ("workspace_project_open_editor_returns_missing_executable_guidance", VerifyMissingExecutableContractAsync),
            ("workspace_project_close_editor_reports_editor_lifecycle_unsupported", VerifyLifecycleUnsupportedContractAsync),
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

    private static async Task VerifyEditorRequiredContractAsync()
    {
        using var harness = ContractHarness.Create("editor_required");
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
        using var harness = ContractHarness.Create("missing_executable");
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
        using var harness = ContractHarness.Create("lifecycle_unsupported");
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

    private static void AssertContains(IEnumerable<string> values, string expected)
    {
        if (!values.Any(value => string.Equals(value, expected, StringComparison.Ordinal)))
        {
            throw new InvalidOperationException($"Expected value '{expected}' was not found.");
        }
    }

    private static void AssertNestedString(JsonElement root, string expected, params string[] path)
    {
        var current = GetNestedElement(root, path);
        if (current.ValueKind != JsonValueKind.String)
        {
            throw new InvalidOperationException($"Expected string at path '{string.Join(".", path)}', got {current.ValueKind}.");
        }

        var actual = current.GetString() ?? string.Empty;
        if (!string.Equals(actual, expected, StringComparison.Ordinal))
        {
            throw new InvalidOperationException($"Expected '{expected}' at path '{string.Join(".", path)}', got '{actual}'.");
        }
    }

    private static void AssertNestedBoolean(JsonElement root, bool expected, params string[] path)
    {
        var current = GetNestedElement(root, path);
        var actual = current.ValueKind switch
        {
            JsonValueKind.True => true,
            JsonValueKind.False => false,
            _ => throw new InvalidOperationException($"Expected boolean at path '{string.Join(".", path)}', got {current.ValueKind}."),
        };

        if (actual != expected)
        {
            throw new InvalidOperationException($"Expected '{expected}' at path '{string.Join(".", path)}', got '{actual}'.");
        }
    }

    private static JsonElement GetNestedElement(JsonElement root, params string[] path)
    {
        var current = root;
        foreach (var segment in path)
        {
            if (current.ValueKind != JsonValueKind.Object || !current.TryGetProperty(segment, out current))
            {
                throw new InvalidOperationException($"Missing property '{segment}' while resolving path '{string.Join(".", path)}'.");
            }
        }

        return current;
    }

    private sealed class ContractHarness : IDisposable
    {
        private readonly string? _previousCentralHome;
        private readonly string _repoRoot;
        private readonly string _tempRoot;
        private readonly EditorProxyService _editorProxy;

        private ContractHarness(
            string repoRoot,
            string tempRoot,
            string? previousCentralHome,
            EditorProxyService editorProxy,
            ProjectRegistryService registry,
            EditorSessionService editorSessions,
            CentralToolDispatcher dispatcher)
        {
            _repoRoot = repoRoot;
            _tempRoot = tempRoot;
            _previousCentralHome = previousCentralHome;
            _editorProxy = editorProxy;
            Registry = registry;
            EditorSessions = editorSessions;
            Dispatcher = dispatcher;
            ProjectRoot = Path.Combine(tempRoot, "project");
        }

        public string ProjectRoot { get; }

        public ProjectRegistryService Registry { get; }

        public EditorSessionService EditorSessions { get; }

        public CentralToolDispatcher Dispatcher { get; }

        public static ContractHarness Create(string name)
        {
            var repoRoot = ResolveRepoRoot();
            var tempRoot = Path.Combine(repoRoot, ".tmp", "host_contracts", $"{name}_{Guid.NewGuid():N}");
            Directory.CreateDirectory(tempRoot);

            var previousCentralHome = Environment.GetEnvironmentVariable("GODOT_DOTNET_MCP_CENTRAL_HOME");
            var centralHome = Path.Combine(tempRoot, "CentralHome");
            Directory.CreateDirectory(centralHome);
            Environment.SetEnvironmentVariable("GODOT_DOTNET_MCP_CENTRAL_HOME", centralHome);

            var configuration = new CentralConfigurationService();
            var editorProcesses = new EditorProcessService();
            var godotInstallations = new GodotInstallationService();
            var godotProjectManager = new GodotProjectManagerProvider(configuration);
            var registry = new ProjectRegistryService();
            var editorSessions = new EditorSessionService(registry);
            var editorProxy = new EditorProxyService();
            var sessionState = new SessionState();
            var attachEndpoint = new EditorAttachEndpoint("127.0.0.1", GetFreeTcpPort());
            var editorSessionCoordinator = new EditorSessionCoordinator(configuration, editorProcesses, editorSessions, godotInstallations, registry, sessionState, attachEndpoint);
            var editorLifecycleCoordinator = new EditorLifecycleCoordinator(configuration, editorProcesses, editorProxy, editorSessionCoordinator, editorSessions, registry, sessionState);
            var dispatcher = new CentralToolDispatcher(configuration, editorProxy, editorProcesses, editorLifecycleCoordinator, editorSessionCoordinator, editorSessions, godotInstallations, godotProjectManager, registry, sessionState);
            var harness = new ContractHarness(repoRoot, tempRoot, previousCentralHome, editorProxy, registry, editorSessions, dispatcher);
            harness.CreateProjectFixture();
            return harness;
        }

        public async Task<string> RegisterProjectAsync()
        {
            var response = await Dispatcher.ExecuteAsync(
                "workspace_project_register",
                SerializeToElement(new { path = ProjectRoot }),
                CancellationToken.None);
            EnsureSuccess(response, "workspace_project_register");

            var payload = SerializeToElement(response.StructuredContent);
            return payload.GetProperty("project").GetProperty("projectId").GetString()
                   ?? throw new InvalidOperationException("Registered project payload did not include projectId.");
        }

        public void Dispose()
        {
            _editorProxy.Dispose();
            Environment.SetEnvironmentVariable("GODOT_DOTNET_MCP_CENTRAL_HOME", _previousCentralHome);
            try
            {
                if (Directory.Exists(_tempRoot))
                {
                    Directory.Delete(_tempRoot, recursive: true);
                }
            }
            catch
            {
            }
        }

        private void CreateProjectFixture()
        {
            Directory.CreateDirectory(ProjectRoot);
            File.WriteAllText(
                Path.Combine(ProjectRoot, "project.godot"),
                """
                ; Engine configuration file.
                config_version=5

                [application]
                config/name="Host Contracts"
                """);
        }

        private static string ResolveRepoRoot()
        {
            var current = new DirectoryInfo(Directory.GetCurrentDirectory());
            while (current is not null)
            {
                if (Directory.Exists(Path.Combine(current.FullName, "central_server"))
                    && Directory.Exists(Path.Combine(current.FullName, "addons")))
                {
                    return current.FullName;
                }

                current = current.Parent;
            }

            throw new InvalidOperationException("Could not resolve repository root for host contract tests.");
        }
    }
}
