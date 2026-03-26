using System.Diagnostics;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Text.Json;
using static GodotDotnetMcp.CentralServer.SmokeAssertionSupport;
using static GodotDotnetMcp.CentralServer.SmokeHttpSupport;
using static GodotDotnetMcp.CentralServer.SmokePayloadSupport;

namespace GodotDotnetMcp.CentralServer;

internal static class SmokeSystemSessionRunner
{
    private const int DefaultAutoLaunchAttachTimeoutMs = 120_000;

    public static async Task<int> RunAsync(string[] args, Stream output, TextWriter error, CancellationToken cancellationToken)
    {
        var attachHost = GetOptionValue(args, "--attach-host") ?? "127.0.0.1";
        var attachPort = ParsePositiveIntOption(args, "--attach-port") ?? GetFreeTcpPort();
        var autoLaunch = HasOption(args, "--auto-launch");
        var requireAutoLaunch = HasOption(args, "--require-auto-launch");
        var cleanupLaunchedEditor = HasOption(args, "--cleanup-launched-editor");
        var projectRootOption = GetOptionValue(args, "--project-root");
        var explicitGodotExecutablePath = GetOptionValue(args, "--godot-executable-path");
        var attachTimeoutMs = ParsePositiveIntOption(args, "--editor-attach-timeout-ms") ?? DefaultAutoLaunchAttachTimeoutMs;

        var configuration = new CentralConfigurationService();
        var editorProcesses = new EditorProcessService();
        var godotInstallations = new GodotInstallationService();
        var godotProjectManager = new GodotProjectManagerProvider(configuration);
        var registry = new ProjectRegistryService();
        var editorSessions = new EditorSessionService(registry);
        using var editorProxy = new EditorProxyService();
        var sessionState = new SessionState();
        var attachEndpoint = new EditorAttachEndpoint(attachHost, attachPort);
        var editorSessionCoordinator = new EditorSessionCoordinator(configuration, editorProcesses, editorSessions, godotInstallations, registry, sessionState, attachEndpoint);
        var editorLifecycleCoordinator = new EditorLifecycleCoordinator(configuration, editorProcesses, editorProxy, editorSessionCoordinator, editorSessions, registry, sessionState);
        var dispatcher = new CentralToolDispatcher(configuration, editorProxy, editorProcesses, editorLifecycleCoordinator, editorSessionCoordinator, editorSessions, godotInstallations, godotProjectManager, registry, sessionState);
        using var smokeCts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);

        await using var attachServer = new EditorAttachHttpServer(
            attachHost,
            attachPort,
            editorSessions,
            error,
            () =>
            {
                smokeCts.Cancel();
                return Task.CompletedTask;
            });
        attachServer.Start(smokeCts.Token);

        try
        {
            await WaitForAttachServerReadyAsync(attachHost, attachPort, smokeCts.Token);
            return autoLaunch
                ? await RunAutoLaunchAsync(
                    output,
                    error,
                    smokeCts.Token,
                    configuration,
                    editorProcesses,
                    editorSessionCoordinator,
                    editorSessions,
                    godotProjectManager,
                    dispatcher,
                    godotInstallations,
                    registry,
                    sessionState,
                    projectRootOption,
                    explicitGodotExecutablePath,
                    attachTimeoutMs,
                    requireAutoLaunch,
                    cleanupLaunchedEditor)
                : await RunReuseSessionAsync(
                    args,
                    output,
                    error,
                    smokeCts.Token,
                    dispatcher,
                    registry,
                    sessionState,
                    attachHost,
                    attachPort);
        }
        finally
        {
            smokeCts.Cancel();
        }
    }

    private static async Task<int> RunReuseSessionAsync(
        string[] args,
        Stream output,
        TextWriter error,
        CancellationToken cancellationToken,
        CentralToolDispatcher dispatcher,
        ProjectRegistryService registry,
        SessionState sessionState,
        string attachHost,
        int attachPort)
    {
        var mockPort = ParsePositiveIntOption(args, "--mock-port") ?? GetFreeTcpPort();
        var projectRoot = GetOptionValue(args, "--project-root")
                          ?? Path.Combine(Path.GetTempPath(), "GodotDotnetMcp", "central_server_session_smoke_" + Guid.NewGuid().ToString("N"));
        var attachedProjectId = string.Empty;
        var missingExecutableProjectId = string.Empty;
        var closeEditorForceUnavailablePayload = default(JsonElement);
        var closeEditorGracefulUnsupportedPayload = default(JsonElement);
        var openEditorMissingExecutablePayload = default(JsonElement);
        var lifecycleStatusPayload = default(JsonElement);
        var restartEditorPayload = default(JsonElement);
        var restartStatusPayload = default(JsonElement);
        var closeEditorSuccessPayload = default(JsonElement);

        try
        {
            Directory.CreateDirectory(projectRoot);
            await File.WriteAllTextAsync(
                Path.Combine(projectRoot, "project.godot"),
                """
                [application]
                config/name="CentralServerSmoke"
                """,
                new UTF8Encoding(encoderShouldEmitUTF8Identifier: false),
                cancellationToken);

            var registerResponse = await dispatcher.ExecuteAsync(
                "workspace_project_register",
                SerializeToElement(new
                {
                    path = projectRoot,
                    source = "smoke_system_session",
                }),
                cancellationToken);
            EnsureSuccess(registerResponse, "workspace_project_register");

            var registerPayload = SerializeToElement(registerResponse.StructuredContent);
            attachedProjectId = registerPayload.GetProperty("project").GetProperty("projectId").GetString() ?? string.Empty;
            if (string.IsNullOrWhiteSpace(attachedProjectId))
            {
                throw new CentralToolException("Smoke register response did not include a projectId.");
            }

            var missingExecutableProjectRoot = Path.Combine(projectRoot, "missing_executable_project");
            Directory.CreateDirectory(missingExecutableProjectRoot);
            await File.WriteAllTextAsync(
                Path.Combine(missingExecutableProjectRoot, "project.godot"),
                """
                [application]
                config/name="CentralServerSmokeMissingExecutable"
                """,
                new UTF8Encoding(encoderShouldEmitUTF8Identifier: false),
                cancellationToken);

            var registerMissingExecutableResponse = await dispatcher.ExecuteAsync(
                "workspace_project_register",
                SerializeToElement(new
                {
                    path = missingExecutableProjectRoot,
                    source = "smoke_open_editor_missing_executable",
                }),
                cancellationToken);
            EnsureSuccess(registerMissingExecutableResponse, "workspace_project_register");
            var registerMissingExecutablePayload = SerializeToElement(registerMissingExecutableResponse.StructuredContent);
            missingExecutableProjectId = registerMissingExecutablePayload.GetProperty("project").GetProperty("projectId").GetString() ?? string.Empty;
            if (string.IsNullOrWhiteSpace(missingExecutableProjectId))
            {
                throw new CentralToolException("Missing-executable smoke register response did not include a projectId.");
            }

            var invalidExecutablePath = Path.Combine(missingExecutableProjectRoot, "Godot-does-not-exist.exe");
            var openEditorMissingExecutableResponse = await dispatcher.ExecuteAsync(
                "workspace_project_open_editor",
                SerializeToElement(new
                {
                    projectId = missingExecutableProjectId,
                    executablePath = invalidExecutablePath,
                    attachTimeoutMs = 2_000,
                }),
                cancellationToken);
            openEditorMissingExecutablePayload = EnsureExpectedError(
                openEditorMissingExecutableResponse,
                "workspace_project_open_editor",
                "godot_executable_not_found");
            EnsureOpenEditorMissingExecutablePayload(
                openEditorMissingExecutablePayload,
                "workspace_project_open_editor",
                missingExecutableProjectId,
                invalidExecutablePath,
                attachHost,
                attachPort);

            await using var mockServer = new MockEditorMcpServer("127.0.0.1", mockPort, attachHost, attachPort, projectRoot);
            mockServer.SetSession(attachedProjectId, "smoke-session", ["system_project_state"]);
            mockServer.Start(cancellationToken);

            var attachResponse = await SendJsonRequestAsync(
                attachHost,
                attachPort,
                "POST",
                "/api/editor/attach",
                BuildMockAttachRequest(attachedProjectId, projectRoot, "smoke-session", ["system_project_state"], mockPort),
                cancellationToken);
            if (!attachResponse.TryGetProperty("success", out var attachSuccess)
                || attachSuccess.ValueKind != JsonValueKind.True)
            {
                throw new CentralToolException("Attach smoke request did not return success=true.");
            }

            var systemResponse = await dispatcher.ExecuteAsync(
                "system_project_state",
                SerializeToElement(new
                {
                    projectId = attachedProjectId,
                    autoLaunchEditor = false,
                    include_runtime_health = false,
                    error_limit = 3,
                }),
                cancellationToken);
            EnsureSuccess(systemResponse, "system_project_state");

            var systemPayload = SerializeToElement(systemResponse.StructuredContent);
            if (!systemPayload.TryGetProperty("centralHostSession", out var centralHostSession))
            {
                throw new CentralToolException("system_project_state result is missing centralHostSession.");
            }

            var lifecycleSummary = centralHostSession.TryGetProperty("editorLifecycle", out var lifecycleElement)
                                   && lifecycleElement.ValueKind == JsonValueKind.Object
                ? lifecycleElement
                : centralHostSession;
            var sessionId = lifecycleSummary.TryGetProperty("sessionId", out var sessionIdElement)
                            && sessionIdElement.ValueKind == JsonValueKind.String
                ? sessionIdElement.GetString() ?? string.Empty
                : string.Empty;
            if (!string.Equals(sessionId, "smoke-session", StringComparison.OrdinalIgnoreCase))
            {
                throw new CentralToolException("system_project_state returned an unexpected sessionId.");
            }

            var resolution = lifecycleSummary.TryGetProperty("resolution", out var resolutionElement)
                             && resolutionElement.ValueKind == JsonValueKind.String
                ? resolutionElement.GetString() ?? string.Empty
                : string.Empty;
            if (!string.Equals(resolution, "reused_ready_session", StringComparison.OrdinalIgnoreCase))
            {
                throw new CentralToolException($"Unexpected centralHostSession.resolution: {resolution}");
            }

            var statusResponse = await dispatcher.ExecuteAsync(
                "workspace_project_status",
                SerializeToElement(new { projectId = attachedProjectId }),
                cancellationToken);
            EnsureSuccess(statusResponse, "workspace_project_status");
            var statusPayload = SerializeToElement(statusResponse.StructuredContent);
            EnsureLifecycleCapabilityUnavailable(statusPayload, "workspace_project_status");

            var closeEditorForceUnavailableResponse = await dispatcher.ExecuteAsync(
                "workspace_project_close_editor",
                SerializeToElement(new
                {
                    projectId = attachedProjectId,
                    force = true,
                    shutdownTimeoutMs = 5_000,
                }),
                cancellationToken);
            closeEditorForceUnavailablePayload = EnsureExpectedError(
                closeEditorForceUnavailableResponse,
                "workspace_project_close_editor",
                "editor_force_unavailable");

            var closeEditorGracefulUnsupportedResponse = await dispatcher.ExecuteAsync(
                "workspace_project_close_editor",
                SerializeToElement(new
                {
                    projectId = attachedProjectId,
                    save = true,
                    shutdownTimeoutMs = 5_000,
                }),
                cancellationToken);
            closeEditorGracefulUnsupportedPayload = EnsureExpectedError(
                closeEditorGracefulUnsupportedResponse,
                "workspace_project_close_editor",
                "editor_lifecycle_unsupported");

            mockServer.SetSession(
                attachedProjectId,
                "smoke-lifecycle",
                ["system_project_state", EditorSessionService.EditorLifecycleCapability]);
            var lifecycleAttachResponse = await SendJsonRequestAsync(
                attachHost,
                attachPort,
                "POST",
                "/api/editor/attach",
                BuildMockAttachRequest(
                    attachedProjectId,
                    projectRoot,
                    "smoke-lifecycle",
                    ["system_project_state", EditorSessionService.EditorLifecycleCapability],
                    mockPort),
                cancellationToken);
            if (!lifecycleAttachResponse.TryGetProperty("success", out var lifecycleAttachSuccess)
                || lifecycleAttachSuccess.ValueKind != JsonValueKind.True)
            {
                throw new CentralToolException("Lifecycle-capable attach smoke request did not return success=true.");
            }

            var lifecycleStatusResponse = await dispatcher.ExecuteAsync(
                "workspace_project_status",
                SerializeToElement(new { projectId = attachedProjectId }),
                cancellationToken);
            EnsureSuccess(lifecycleStatusResponse, "workspace_project_status");
            lifecycleStatusPayload = SerializeToElement(lifecycleStatusResponse.StructuredContent);
            EnsureLifecycleCapabilityAvailable(lifecycleStatusPayload, "workspace_project_status");
            EnsurePayloadSessionId(lifecycleStatusPayload, "workspace_project_status", "smoke-lifecycle");

            var restartEditorResponse = await dispatcher.ExecuteAsync(
                "workspace_project_restart_editor",
                SerializeToElement(new
                {
                    projectId = attachedProjectId,
                    save = true,
                    shutdownTimeoutMs = 5_000,
                    attachTimeoutMs = 5_000,
                }),
                cancellationToken);
            EnsureSuccess(restartEditorResponse, "workspace_project_restart_editor");
            restartEditorPayload = SerializeToElement(restartEditorResponse.StructuredContent);
            EnsureLifecycleToolSessionReady(restartEditorPayload, "workspace_project_restart_editor");
            EnsurePayloadSessionIdChanged(restartEditorPayload, "workspace_project_restart_editor", "smoke-lifecycle");

            var restartStatusResponse = await dispatcher.ExecuteAsync(
                "workspace_project_status",
                SerializeToElement(new { projectId = attachedProjectId }),
                cancellationToken);
            EnsureSuccess(restartStatusResponse, "workspace_project_status");
            restartStatusPayload = SerializeToElement(restartStatusResponse.StructuredContent);
            EnsureLifecycleCapabilityAvailable(restartStatusPayload, "workspace_project_status");

            var closeEditorSuccessResponse = await dispatcher.ExecuteAsync(
                "workspace_project_close_editor",
                SerializeToElement(new
                {
                    projectId = attachedProjectId,
                    save = true,
                    shutdownTimeoutMs = 5_000,
                }),
                cancellationToken);
            EnsureSuccess(closeEditorSuccessResponse, "workspace_project_close_editor");
            closeEditorSuccessPayload = SerializeToElement(closeEditorSuccessResponse.StructuredContent);
            EnsureLifecycleToolClosed(closeEditorSuccessPayload, "workspace_project_close_editor");

            var removeResponse = await dispatcher.ExecuteAsync(
                "workspace_project_remove",
                SerializeToElement(new { projectId = attachedProjectId }),
                cancellationToken);
            EnsureSuccess(removeResponse, "workspace_project_remove");
            attachedProjectId = string.Empty;

            var summary = new
            {
                success = true,
                skipped = false,
                mode = "reuse_session",
                attachHost,
                attachPort,
                mockPort,
                projectId = lifecycleSummary.TryGetProperty("projectId", out var lifecycleProjectId)
                    && lifecycleProjectId.ValueKind == JsonValueKind.String
                        ? lifecycleProjectId.GetString()
                        : attachedProjectId,
                projectPath = lifecycleSummary.TryGetProperty("projectPath", out var lifecycleProjectPath)
                    && lifecycleProjectPath.ValueKind == JsonValueKind.String
                        ? lifecycleProjectPath.GetString()
                        : projectRoot,
                sessionId,
                resolution,
                endpoint = centralHostSession.TryGetProperty("endpoint", out var endpointElement)
                    && endpointElement.ValueKind == JsonValueKind.String
                        ? endpointElement.GetString()
                        : string.Empty,
                centralHostSession = DeserializeToObject(centralHostSession),
                systemResult = DeserializeToObject(systemPayload),
                workspaceStatus = DeserializeToObject(statusPayload),
                forceCloseUnavailableResult = closeEditorForceUnavailablePayload.ValueKind == JsonValueKind.Undefined
                    ? null
                    : DeserializeToObject(closeEditorForceUnavailablePayload),
                gracefulCloseUnsupportedResult = closeEditorGracefulUnsupportedPayload.ValueKind == JsonValueKind.Undefined
                    ? null
                    : DeserializeToObject(closeEditorGracefulUnsupportedPayload),
                openEditorMissingExecutableResult = openEditorMissingExecutablePayload.ValueKind == JsonValueKind.Undefined
                    ? null
                    : DeserializeToObject(openEditorMissingExecutablePayload),
                lifecycleStatus = lifecycleStatusPayload.ValueKind == JsonValueKind.Undefined
                    ? null
                    : DeserializeToObject(lifecycleStatusPayload),
                restartEditorResult = restartEditorPayload.ValueKind == JsonValueKind.Undefined
                    ? null
                    : DeserializeToObject(restartEditorPayload),
                restartStatus = restartStatusPayload.ValueKind == JsonValueKind.Undefined
                    ? null
                    : DeserializeToObject(restartStatusPayload),
                closeEditorResult = closeEditorSuccessPayload.ValueKind == JsonValueKind.Undefined
                    ? null
                    : DeserializeToObject(closeEditorSuccessPayload),
                mockLifecycleActions = mockServer.LifecycleActions,
                mockForwardRequest = mockServer.LastRequestPayload is null
                    ? null
                    : DeserializeToObject(JsonDocument.Parse(mockServer.LastRequestPayload).RootElement),
            };

            await WritePlainJsonAsync(output, summary, cancellationToken);
            return 0;
        }
        catch (Exception ex)
        {
            await WritePlainJsonAsync(output, new
            {
                success = false,
                skipped = false,
                mode = "reuse_session",
                error = ex.Message,
                exception = ex.GetType().Name,
                detail = ex.ToString(),
                attachHost,
                attachPort,
                mockPort,
                projectRoot,
                activeProjectId = sessionState.ActiveProjectId,
                activeEditorSessionId = sessionState.ActiveEditorSessionId,
            }, cancellationToken);
            await error.WriteLineAsync($"[CentralServerSmoke] {ex.Message}");
            await error.FlushAsync();
            return 1;
        }
        finally
        {
            if (!string.IsNullOrWhiteSpace(missingExecutableProjectId))
            {
                registry.RemoveProject(missingExecutableProjectId, null, out _);
            }

            if (!string.IsNullOrWhiteSpace(attachedProjectId))
            {
                registry.RemoveProject(attachedProjectId, null, out _);
            }

            if (Directory.Exists(projectRoot))
            {
                try
                {
                    Directory.Delete(projectRoot, recursive: true);
                }
                catch
                {
                }
            }
        }
    }

    private static async Task<int> RunAutoLaunchAsync(
        Stream output,
        TextWriter error,
        CancellationToken cancellationToken,
        CentralConfigurationService configuration,
        EditorProcessService editorProcesses,
        EditorSessionCoordinator editorSessionCoordinator,
        EditorSessionService editorSessions,
        GodotProjectManagerProvider godotProjectManager,
        CentralToolDispatcher dispatcher,
        GodotInstallationService godotInstallations,
        ProjectRegistryService registry,
        SessionState sessionState,
        string? projectRootOption,
        string? explicitGodotExecutablePath,
        int attachTimeoutMs,
        bool requireAutoLaunch,
        bool cleanupLaunchedEditor)
    {
        var projectResolution = ResolveAutoLaunchProjectRoot(projectRootOption);
        if (projectResolution.ShouldSkip)
        {
            if (requireAutoLaunch)
            {
                await WritePlainJsonAsync(output, new
                {
                    success = false,
                    skipped = true,
                    mode = "auto_launch",
                    required = true,
                    error = projectResolution.Message,
                    projectRoot = projectResolution.ProjectRoot,
                }, cancellationToken);
                return 1;
            }

            await WritePlainJsonAsync(output, new
            {
                success = true,
                skipped = true,
                mode = "auto_launch",
                reason = projectResolution.Message,
                projectRoot = projectResolution.ProjectRoot,
            }, cancellationToken);
            return 0;
        }

        var projectRoot = projectResolution.ProjectRoot;
        if (string.IsNullOrWhiteSpace(projectRoot))
        {
            throw new CentralToolException("Auto-launch smoke did not resolve a project root.");
        }

        var existingProject = registry.ResolveProject(null, projectRoot);
        var projectPreviouslyRegistered = existingProject is not null;
        var originalGodotExecutablePath = existingProject?.GodotExecutablePath;
        var projectId = existingProject?.ProjectId ?? string.Empty;
        var cleanupProjectId = string.Empty;
        var launchedProcessId = 0;
        var launchedAlreadyRunning = false;
        var cleanupApplied = false;
        var executablePath = string.Empty;
        var executableSource = string.Empty;
        using var interruptEditorProxy = new EditorProxyService();
        var interruptEditorLifecycleCoordinator = new EditorLifecycleCoordinator(configuration, editorProcesses, interruptEditorProxy, editorSessionCoordinator, editorSessions, registry, sessionState);
        var interruptDispatcher = new CentralToolDispatcher(
            configuration,
            interruptEditorProxy,
            editorProcesses,
            interruptEditorLifecycleCoordinator,
            editorSessionCoordinator,
            editorSessions,
            godotInstallations,
            godotProjectManager,
            registry,
            sessionState);
        var systemPayload = default(JsonElement);
        var runtimeNotRunningPayload = default(JsonElement);
        var projectRunPayload = default(JsonElement);
        var runtimeControlDisabledPayload = default(JsonElement);
        var runtimeControlPayload = default(JsonElement);
        var invalidRuntimeCapturePayload = default(JsonElement);
        var invalidRuntimeInputPayload = default(JsonElement);
        var runtimeSessionLostPayload = default(JsonElement);
        var runtimeSessionLostStopPayload = default(JsonElement);
        var projectRerunPayload = default(JsonElement);
        var runtimeControlReenabledPayload = default(JsonElement);
        var runtimeStepPayload = default(JsonElement);
        var projectStopPayload = default(JsonElement);
        var residentStatusPayload = default(JsonElement);
        var restartEditorPayload = default(JsonElement);
        var reopenEditorPayload = default(JsonElement);
        var closeEditorPayload = default(JsonElement);
        var captureFilePath = string.Empty;

        try
        {
            var registerResponse = await dispatcher.ExecuteAsync(
                "workspace_project_register",
                SerializeToElement(new
                {
                    path = projectRoot,
                    source = "smoke_system_session_auto_launch",
                }),
                cancellationToken);
            EnsureSuccess(registerResponse, "workspace_project_register");

            var registerPayload = SerializeToElement(registerResponse.StructuredContent);
            projectId = registerPayload.GetProperty("project").GetProperty("projectId").GetString() ?? string.Empty;
            if (string.IsNullOrWhiteSpace(projectId))
            {
                throw new CentralToolException("Auto-launch smoke register response did not include a projectId.");
            }

            if (!projectPreviouslyRegistered)
            {
                cleanupProjectId = projectId;
            }

            var registeredProject = registry.ResolveProject(projectId, null)
                                  ?? throw new CentralToolException("Registered project was not found after registration.");
            var executableResolution = ResolveAutoLaunchExecutable(
                configuration,
                godotInstallations,
                registry,
                registeredProject,
                explicitGodotExecutablePath,
                out var skipMessage);
            if (skipMessage is not null)
            {
                if (requireAutoLaunch)
                {
                    await WritePlainJsonAsync(output, new
                    {
                        success = false,
                        skipped = true,
                        mode = "auto_launch",
                        required = true,
                        error = skipMessage,
                        projectId,
                        projectRoot,
                    }, cancellationToken);
                    return 1;
                }

                await WritePlainJsonAsync(output, new
                {
                    success = true,
                    skipped = true,
                    mode = "auto_launch",
                    reason = skipMessage,
                    projectId,
                    projectRoot,
                }, cancellationToken);
                return 0;
            }

            executablePath = executableResolution?.ExecutablePath ?? string.Empty;
            executableSource = executableResolution?.Source ?? string.Empty;

            var systemResponse = await dispatcher.ExecuteAsync(
                "system_project_state",
                SerializeToElement(new
                {
                    projectId,
                    autoLaunchEditor = true,
                    editorAttachTimeoutMs = attachTimeoutMs,
                    include_runtime_health = false,
                    error_limit = 3,
                }),
                cancellationToken);

            systemPayload = SerializeToElement(systemResponse.StructuredContent);
            TrackLaunchFromPayload(systemPayload, ref launchedProcessId, ref launchedAlreadyRunning);
            EnsureSuccess(systemResponse, "system_project_state");

            if (!systemPayload.TryGetProperty("centralHostSession", out var centralHostSession))
            {
                throw new CentralToolException("system_project_state result is missing centralHostSession.");
            }

            var lifecycleSummary = centralHostSession.TryGetProperty("editorLifecycle", out var lifecycleElement)
                                   && lifecycleElement.ValueKind == JsonValueKind.Object
                ? lifecycleElement
                : centralHostSession;
            var resolution = lifecycleSummary.TryGetProperty("resolution", out var resolutionElement)
                             && resolutionElement.ValueKind == JsonValueKind.String
                ? resolutionElement.GetString() ?? string.Empty
                : string.Empty;
            if (!IsExpectedAutoLaunchResolution(resolution))
            {
                throw new CentralToolException($"Unexpected centralHostSession.resolution: {resolution}");
            }

            var statusResponse = await dispatcher.ExecuteAsync(
                "workspace_project_status",
                SerializeToElement(new { projectId }),
                cancellationToken);
            EnsureSuccess(statusResponse, "workspace_project_status");

            var runtimeNotRunningResponse = await dispatcher.ExecuteAsync(
                "system_runtime_control",
                SerializeToElement(new
                {
                    projectId,
                    autoLaunchEditor = true,
                    editorAttachTimeoutMs = attachTimeoutMs,
                    action = "enable",
                    timeout_ms = 500,
                }),
                cancellationToken);
            runtimeNotRunningPayload = EnsureExpectedError(
                runtimeNotRunningResponse,
                "system_runtime_control",
                "runtime_not_running");
            EnsurePayloadDataObject(runtimeNotRunningPayload, "editor_context", JsonValueKind.Object, "system_runtime_control");
            EnsurePayloadDataObject(runtimeNotRunningPayload, "hint", JsonValueKind.String, "system_runtime_control");

            var projectRunResponse = await dispatcher.ExecuteAsync(
                "system_project_run",
                SerializeToElement(new
                {
                    projectId,
                    autoLaunchEditor = true,
                    editorAttachTimeoutMs = attachTimeoutMs,
                }),
                cancellationToken);
            EnsureSuccess(projectRunResponse, "system_project_run");
            projectRunPayload = SerializeToElement(projectRunResponse.StructuredContent);

            var runtimeControlDisabledResponse = await dispatcher.ExecuteAsync(
                "system_runtime_step",
                SerializeToElement(new
                {
                    projectId,
                    autoLaunchEditor = true,
                    editorAttachTimeoutMs = attachTimeoutMs,
                    wait_frames = 0,
                    capture = false,
                }),
                cancellationToken);
            runtimeControlDisabledPayload = EnsureExpectedError(
                runtimeControlDisabledResponse,
                "system_runtime_step",
                "runtime_control_disabled");
            EnsurePayloadDataObject(runtimeControlDisabledPayload, "editor_context", JsonValueKind.Object, "system_runtime_step");
            EnsurePayloadDataObject(runtimeControlDisabledPayload, "hint", JsonValueKind.String, "system_runtime_step");

            var runtimeControlTimeoutMs = Math.Min(attachTimeoutMs, 60_000);
            var runtimeControlResponse = await dispatcher.ExecuteAsync(
                "system_runtime_control",
                SerializeToElement(new
                {
                    projectId,
                    autoLaunchEditor = true,
                    editorAttachTimeoutMs = attachTimeoutMs,
                    action = "enable",
                    timeout_ms = runtimeControlTimeoutMs,
                }),
                cancellationToken);
            EnsureSuccess(runtimeControlResponse, "system_runtime_control");
            runtimeControlPayload = SerializeToElement(runtimeControlResponse.StructuredContent);

            var invalidRuntimeCaptureResponse = await dispatcher.ExecuteAsync(
                "system_runtime_capture",
                SerializeToElement(new
                {
                    projectId,
                    autoLaunchEditor = true,
                    editorAttachTimeoutMs = attachTimeoutMs,
                    frame_count = 0,
                }),
                cancellationToken);
            invalidRuntimeCapturePayload = EnsureExpectedError(
                invalidRuntimeCaptureResponse,
                "system_runtime_capture",
                "invalid_argument");
            EnsurePayloadDataObject(invalidRuntimeCapturePayload, "tool_name", JsonValueKind.String, "system_runtime_capture", "system_runtime_capture");
            EnsurePayloadDataObject(invalidRuntimeCapturePayload, "hint", JsonValueKind.String, "system_runtime_capture");

            var invalidRuntimeInputResponse = await dispatcher.ExecuteAsync(
                "system_runtime_input",
                SerializeToElement(new
                {
                    projectId,
                    autoLaunchEditor = true,
                    editorAttachTimeoutMs = attachTimeoutMs,
                    timeout_ms = 2_000,
                    inputs = new[]
                    {
                        new
                        {
                            kind = "action",
                            target = "__missing_runtime_action__",
                            op = "tap",
                        }
                    },
                }),
                cancellationToken);
            invalidRuntimeInputPayload = EnsureExpectedError(
                invalidRuntimeInputResponse,
                "system_runtime_input",
                "invalid_argument");
            EnsurePayloadDataObject(invalidRuntimeInputPayload, "editor_context", JsonValueKind.Object, "system_runtime_input");
            EnsurePayloadDataObject(invalidRuntimeInputPayload, "runtime_context", JsonValueKind.Object, "system_runtime_input");
            EnsurePayloadDataObject(invalidRuntimeInputPayload, "runtime_state", JsonValueKind.Object, "system_runtime_input");
            EnsurePayloadDataObject(invalidRuntimeInputPayload, "hint", JsonValueKind.String, "system_runtime_input");

            var runtimeSessionLostTask = dispatcher.ExecuteAsync(
                "system_runtime_step",
                SerializeToElement(new
                {
                    projectId,
                    autoLaunchEditor = true,
                    editorAttachTimeoutMs = attachTimeoutMs,
                    wait_frames = 3_000,
                    capture = false,
                    timeout_ms = 30_000,
                }),
                cancellationToken);

            await Task.Delay(500, cancellationToken);
            if (runtimeSessionLostTask.IsCompleted)
            {
                var completedRuntimeSessionLostResponse = await runtimeSessionLostTask;
                throw new CentralToolException(
                    "runtime session loss smoke step completed before project_stop. Payload: "
                    + TrySerializeForDiagnostic(completedRuntimeSessionLostResponse.StructuredContent));
            }

            var runtimeSessionLostStopResponse = await interruptDispatcher.ExecuteAsync(
                "system_project_stop",
                SerializeToElement(new
                {
                    projectId,
                    autoLaunchEditor = false,
                    editorAttachTimeoutMs = attachTimeoutMs,
                }),
                cancellationToken);
            EnsureSuccess(runtimeSessionLostStopResponse, "system_project_stop");
            runtimeSessionLostStopPayload = SerializeToElement(runtimeSessionLostStopResponse.StructuredContent);

            var runtimeSessionLostResponse = await runtimeSessionLostTask;
            runtimeSessionLostPayload = EnsureExpectedError(
                runtimeSessionLostResponse,
                "system_runtime_step",
                "runtime_session_lost");
            EnsurePayloadDataObject(runtimeSessionLostPayload, "editor_context", JsonValueKind.Object, "system_runtime_step");
            EnsurePayloadDataObject(runtimeSessionLostPayload, "hint", JsonValueKind.String, "system_runtime_step");
            EnsurePayloadDataObject(runtimeSessionLostPayload, "session_id", JsonValueKind.Number, "system_runtime_step");

            var projectRerunResponse = await dispatcher.ExecuteAsync(
                "system_project_run",
                SerializeToElement(new
                {
                    projectId,
                    autoLaunchEditor = true,
                    editorAttachTimeoutMs = attachTimeoutMs,
                }),
                cancellationToken);
            EnsureSuccess(projectRerunResponse, "system_project_run");
            projectRerunPayload = SerializeToElement(projectRerunResponse.StructuredContent);

            var runtimeControlReenabledResponse = await dispatcher.ExecuteAsync(
                "system_runtime_control",
                SerializeToElement(new
                {
                    projectId,
                    autoLaunchEditor = true,
                    editorAttachTimeoutMs = attachTimeoutMs,
                    action = "enable",
                    timeout_ms = runtimeControlTimeoutMs,
                }),
                cancellationToken);
            EnsureSuccess(runtimeControlReenabledResponse, "system_runtime_control");
            runtimeControlReenabledPayload = SerializeToElement(runtimeControlReenabledResponse.StructuredContent);

            var runtimeStepResponse = await dispatcher.ExecuteAsync(
                "system_runtime_step",
                SerializeToElement(new
                {
                    projectId,
                    autoLaunchEditor = true,
                    editorAttachTimeoutMs = attachTimeoutMs,
                    wait_frames = 3,
                    capture = true,
                }),
                cancellationToken);
            EnsureSuccess(runtimeStepResponse, "system_runtime_step");
            runtimeStepPayload = SerializeToElement(runtimeStepResponse.StructuredContent);
            captureFilePath = ExtractRuntimeCaptureFilePath(runtimeStepPayload);
            EnsureRuntimeCaptureFile(captureFilePath);

            var projectStopResponse = await dispatcher.ExecuteAsync(
                "system_project_stop",
                SerializeToElement(new
                {
                    projectId,
                    autoLaunchEditor = false,
                    editorAttachTimeoutMs = attachTimeoutMs,
                }),
                cancellationToken);
            EnsureSuccess(projectStopResponse, "system_project_stop");
            projectStopPayload = SerializeToElement(projectStopResponse.StructuredContent);

            var residentStatusResponse = await dispatcher.ExecuteAsync(
                "workspace_project_status",
                SerializeToElement(new { projectId }),
                cancellationToken);
            EnsureSuccess(residentStatusResponse, "workspace_project_status");
            residentStatusPayload = SerializeToElement(residentStatusResponse.StructuredContent);
            EnsureResidentEditorAfterStop(residentStatusPayload);

            var restartEditorResponse = await dispatcher.ExecuteAsync(
                "workspace_project_restart_editor",
                SerializeToElement(new
                {
                    projectId,
                    save = true,
                    attachTimeoutMs,
                    shutdownTimeoutMs = 60_000,
                }),
                cancellationToken);
            EnsureSuccess(restartEditorResponse, "workspace_project_restart_editor");
            restartEditorPayload = SerializeToElement(restartEditorResponse.StructuredContent);
            TrackCurrentProcessFromPayload(restartEditorPayload, ref launchedProcessId);
            EnsureLifecycleToolSessionReady(restartEditorPayload, "workspace_project_restart_editor");

            var reopenEditorResponse = await dispatcher.ExecuteAsync(
                "workspace_project_open_editor",
                SerializeToElement(new
                {
                    projectId,
                    attachTimeoutMs,
                }),
                cancellationToken);
            EnsureSuccess(reopenEditorResponse, "workspace_project_open_editor");
            reopenEditorPayload = SerializeToElement(reopenEditorResponse.StructuredContent);
            TrackCurrentProcessFromPayload(reopenEditorPayload, ref launchedProcessId);
            EnsureLifecycleToolSessionReady(reopenEditorPayload, "workspace_project_open_editor");

            if (cleanupLaunchedEditor)
            {
                var closeEditorResponse = await dispatcher.ExecuteAsync(
                    "workspace_project_close_editor",
                    SerializeToElement(new
                    {
                        projectId,
                        save = true,
                        shutdownTimeoutMs = 60_000,
                    }),
                    cancellationToken);
                EnsureSuccess(closeEditorResponse, "workspace_project_close_editor");
                closeEditorPayload = SerializeToElement(closeEditorResponse.StructuredContent);
                EnsureLifecycleToolClosed(closeEditorPayload, "workspace_project_close_editor");
                cleanupApplied = true;
                launchedProcessId = 0;
            }

            var summary = new
            {
                success = true,
                skipped = false,
                mode = "auto_launch",
                projectId,
                projectRoot,
                executablePath,
                executableSource,
                resolution,
                centralHostSession = DeserializeToObject(centralHostSession),
                systemResult = DeserializeToObject(systemPayload),
                workspaceStatus = DeserializeToObject(SerializeToElement(statusResponse.StructuredContent)),
                runtimeNotRunningResult = DeserializeToObject(runtimeNotRunningPayload),
                projectRunResult = DeserializeToObject(projectRunPayload),
                runtimeControlDisabledResult = DeserializeToObject(runtimeControlDisabledPayload),
                runtimeControlResult = DeserializeToObject(runtimeControlPayload),
                invalidRuntimeCaptureResult = DeserializeToObject(invalidRuntimeCapturePayload),
                invalidRuntimeInputResult = DeserializeToObject(invalidRuntimeInputPayload),
                runtimeSessionLostStopResult = DeserializeToObject(runtimeSessionLostStopPayload),
                runtimeSessionLostResult = DeserializeToObject(runtimeSessionLostPayload),
                projectRerunResult = DeserializeToObject(projectRerunPayload),
                runtimeControlReenabledResult = DeserializeToObject(runtimeControlReenabledPayload),
                runtimeStepResult = DeserializeToObject(runtimeStepPayload),
                projectStopResult = DeserializeToObject(projectStopPayload),
                residentStatusAfterStop = DeserializeToObject(residentStatusPayload),
                restartEditorResult = DeserializeToObject(restartEditorPayload),
                reopenEditorResult = DeserializeToObject(reopenEditorPayload),
                closeEditorResult = closeEditorPayload.ValueKind == JsonValueKind.Undefined
                    ? null
                    : DeserializeToObject(closeEditorPayload),
                captureFilePath,
                cleanupRequested = cleanupLaunchedEditor,
                cleanupApplied,
            };

            await WritePlainJsonAsync(output, summary, cancellationToken);
            return 0;
        }
        catch (Exception ex)
        {
            await WritePlainJsonAsync(output, new
            {
                success = false,
                skipped = false,
                mode = "auto_launch",
                error = ex.Message,
                exception = ex.GetType().Name,
                detail = ex.ToString(),
                projectId,
                projectRoot,
                executablePath,
                executableSource,
                captureFilePath,
                launchedProcessId,
                launchedAlreadyRunning,
                cleanupRequested = cleanupLaunchedEditor,
                cleanupApplied,
                activeProjectId = sessionState.ActiveProjectId,
                activeEditorSessionId = sessionState.ActiveEditorSessionId,
                systemPayload = systemPayload.ValueKind == JsonValueKind.Undefined
                    ? null
                    : DeserializeToObject(systemPayload),
                runtimeNotRunningPayload = runtimeNotRunningPayload.ValueKind == JsonValueKind.Undefined
                    ? null
                    : DeserializeToObject(runtimeNotRunningPayload),
                projectRunPayload = projectRunPayload.ValueKind == JsonValueKind.Undefined
                    ? null
                    : DeserializeToObject(projectRunPayload),
                runtimeControlDisabledPayload = runtimeControlDisabledPayload.ValueKind == JsonValueKind.Undefined
                    ? null
                    : DeserializeToObject(runtimeControlDisabledPayload),
                runtimeControlPayload = runtimeControlPayload.ValueKind == JsonValueKind.Undefined
                    ? null
                    : DeserializeToObject(runtimeControlPayload),
                invalidRuntimeCapturePayload = invalidRuntimeCapturePayload.ValueKind == JsonValueKind.Undefined
                    ? null
                    : DeserializeToObject(invalidRuntimeCapturePayload),
                invalidRuntimeInputPayload = invalidRuntimeInputPayload.ValueKind == JsonValueKind.Undefined
                    ? null
                    : DeserializeToObject(invalidRuntimeInputPayload),
                runtimeSessionLostStopPayload = runtimeSessionLostStopPayload.ValueKind == JsonValueKind.Undefined
                    ? null
                    : DeserializeToObject(runtimeSessionLostStopPayload),
                runtimeSessionLostPayload = runtimeSessionLostPayload.ValueKind == JsonValueKind.Undefined
                    ? null
                    : DeserializeToObject(runtimeSessionLostPayload),
                projectRerunPayload = projectRerunPayload.ValueKind == JsonValueKind.Undefined
                    ? null
                    : DeserializeToObject(projectRerunPayload),
                runtimeControlReenabledPayload = runtimeControlReenabledPayload.ValueKind == JsonValueKind.Undefined
                    ? null
                    : DeserializeToObject(runtimeControlReenabledPayload),
                runtimeStepPayload = runtimeStepPayload.ValueKind == JsonValueKind.Undefined
                    ? null
                    : DeserializeToObject(runtimeStepPayload),
                projectStopPayload = projectStopPayload.ValueKind == JsonValueKind.Undefined
                    ? null
                    : DeserializeToObject(projectStopPayload),
                residentStatusPayload = residentStatusPayload.ValueKind == JsonValueKind.Undefined
                    ? null
                    : DeserializeToObject(residentStatusPayload),
                restartEditorPayload = restartEditorPayload.ValueKind == JsonValueKind.Undefined
                    ? null
                    : DeserializeToObject(restartEditorPayload),
                reopenEditorPayload = reopenEditorPayload.ValueKind == JsonValueKind.Undefined
                    ? null
                    : DeserializeToObject(reopenEditorPayload),
                closeEditorPayload = closeEditorPayload.ValueKind == JsonValueKind.Undefined
                    ? null
                    : DeserializeToObject(closeEditorPayload),
            }, cancellationToken);
            await error.WriteLineAsync($"[CentralServerSmoke] {ex.Message}");
            await error.FlushAsync();
            return 1;
        }
        finally
        {
            if (cleanupLaunchedEditor && launchedProcessId > 0 && !launchedAlreadyRunning)
            {
                TryKillProcessTree(launchedProcessId);
                cleanupApplied = true;
            }

            if (projectPreviouslyRegistered && !string.IsNullOrWhiteSpace(projectId))
            {
                try
                {
                    registry.UpdateGodotExecutablePath(projectId, originalGodotExecutablePath);
                }
                catch
                {
                }
            }
            else if (cleanupLaunchedEditor && !string.IsNullOrWhiteSpace(cleanupProjectId))
            {
                registry.RemoveProject(cleanupProjectId, null, out _);
            }
        }
    }

    private static AutoLaunchProjectResolution ResolveAutoLaunchProjectRoot(string? explicitProjectRoot)
    {
        if (!string.IsNullOrWhiteSpace(explicitProjectRoot))
        {
            var normalized = Path.GetFullPath(Environment.ExpandEnvironmentVariables(explicitProjectRoot));
            EnsureValidAutoLaunchProjectRoot(normalized, explicitProjectRoot);
            return AutoLaunchProjectResolution.FromProject(normalized);
        }

        foreach (var candidate in GetDefaultAutoLaunchProjectRootCandidates())
        {
            if (IsValidAutoLaunchProjectRoot(candidate))
            {
                return AutoLaunchProjectResolution.FromProject(candidate);
            }
        }

        return AutoLaunchProjectResolution.Skip(
            "No default auto-launch smoke project was found. Pass --project-root to a Godot project with the plugin enabled.",
            null);
    }

    private static string[] GetDefaultAutoLaunchProjectRootCandidates()
    {
        var candidates = new List<string>
        {
            Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "..", "Mechoes")),
            Path.GetFullPath(Path.Combine(Directory.GetCurrentDirectory(), "..", "Mechoes")),
            Path.GetFullPath(Path.Combine(Directory.GetCurrentDirectory(), "Mechoes")),
        };

        return candidates
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToArray();
    }

    private static void EnsureValidAutoLaunchProjectRoot(string normalizedProjectRoot, string originalProjectRoot)
    {
        if (!Directory.Exists(normalizedProjectRoot))
        {
            throw new CentralToolException($"Auto-launch smoke project directory not found: {originalProjectRoot}");
        }

        if (!File.Exists(Path.Combine(normalizedProjectRoot, "project.godot")))
        {
            throw new CentralToolException($"Auto-launch smoke project is missing project.godot: {normalizedProjectRoot}");
        }

        if (!File.Exists(Path.Combine(normalizedProjectRoot, "addons", "godot_dotnet_mcp", "plugin.cfg")))
        {
            throw new CentralToolException($"Auto-launch smoke project does not contain addons/godot_dotnet_mcp/plugin.cfg: {normalizedProjectRoot}");
        }
    }

    private static bool IsValidAutoLaunchProjectRoot(string candidate)
    {
        return Directory.Exists(candidate)
               && File.Exists(Path.Combine(candidate, "project.godot"))
               && File.Exists(Path.Combine(candidate, "addons", "godot_dotnet_mcp", "plugin.cfg"));
    }

    private static GodotInstallationService.GodotExecutableResolution? ResolveAutoLaunchExecutable(
        CentralConfigurationService configuration,
        GodotInstallationService godotInstallations,
        ProjectRegistryService registry,
        ProjectRegistryService.RegisteredProject project,
        string? explicitGodotExecutablePath,
        out string? skipMessage)
    {
        skipMessage = null;

        if (!string.IsNullOrWhiteSpace(explicitGodotExecutablePath))
        {
            var normalizedPath = Path.GetFullPath(Environment.ExpandEnvironmentVariables(explicitGodotExecutablePath));
            registry.UpdateGodotExecutablePath(project.ProjectId, normalizedPath);
            return new GodotInstallationService.GodotExecutableResolution
            {
                ExecutablePath = normalizedPath,
                Source = "explicit",
            };
        }

        try
        {
            return godotInstallations.ResolveExecutable(project, string.Empty, configuration);
        }
        catch (CentralToolException)
        {
            if (string.IsNullOrWhiteSpace(project.GodotExecutablePath)
                && !configuration.HasDefaultGodotExecutable
                && godotInstallations.ListCandidates().Count == 0)
            {
                skipMessage = "No Godot executable is configured or discoverable on this machine. Pass --godot-executable-path to run the real auto-launch smoke.";
                return null;
            }

            throw;
        }
    }

    private static bool IsExpectedAutoLaunchResolution(string resolution)
    {
        return string.Equals(resolution, "launched_editor", StringComparison.OrdinalIgnoreCase)
               || string.Equals(resolution, "reused_running_editor", StringComparison.OrdinalIgnoreCase)
               || string.Equals(resolution, "reused_ready_session", StringComparison.OrdinalIgnoreCase);
    }

    private static string ExtractRuntimeCaptureFilePath(JsonElement runtimeStepPayload)
    {
        if (runtimeStepPayload.ValueKind != JsonValueKind.Object)
        {
            throw new CentralToolException("system_runtime_step did not return an object payload.");
        }

        if (!runtimeStepPayload.TryGetProperty("data", out var dataElement) || dataElement.ValueKind != JsonValueKind.Object)
        {
            throw new CentralToolException("system_runtime_step did not return a data object.");
        }

        if (dataElement.TryGetProperty("file_path", out var directFilePath)
            && directFilePath.ValueKind == JsonValueKind.String
            && !string.IsNullOrWhiteSpace(directFilePath.GetString()))
        {
            return directFilePath.GetString()!;
        }

        if (dataElement.TryGetProperty("frame", out var frameElement)
            && frameElement.ValueKind == JsonValueKind.Object
            && frameElement.TryGetProperty("file_path", out var nestedFilePath)
            && nestedFilePath.ValueKind == JsonValueKind.String
            && !string.IsNullOrWhiteSpace(nestedFilePath.GetString()))
        {
            return nestedFilePath.GetString()!;
        }

        throw new CentralToolException("system_runtime_step did not return a capture file path.");
    }

    private static void EnsureRuntimeCaptureFile(string filePath)
    {
        if (string.IsNullOrWhiteSpace(filePath))
        {
            throw new CentralToolException("Runtime capture file path is empty.");
        }

        if (!File.Exists(filePath))
        {
            throw new CentralToolException($"Runtime capture file was not created: {filePath}");
        }

        using var stream = File.OpenRead(filePath);
        Span<byte> signature = stackalloc byte[8];
        var read = stream.Read(signature);
        if (read < 8
            || signature[0] != 0x89
            || signature[1] != 0x50
            || signature[2] != 0x4E
            || signature[3] != 0x47
            || signature[4] != 0x0D
            || signature[5] != 0x0A
            || signature[6] != 0x1A
            || signature[7] != 0x0A)
        {
            throw new CentralToolException($"Runtime capture file is not a valid PNG: {filePath}");
        }
    }

    private static void EnsureResidentEditorAfterStop(JsonElement payload)
    {
        if (payload.ValueKind != JsonValueKind.Object)
        {
            throw new CentralToolException("workspace_project_status after stop did not return an object payload.");
        }

        if (!payload.TryGetProperty("editorLifecycle", out var lifecycle)
            || lifecycle.ValueKind != JsonValueKind.Object)
        {
            throw new CentralToolException("workspace_project_status after stop is missing editorLifecycle.");
        }

        if (!lifecycle.TryGetProperty("resident", out var residentElement)
            || residentElement.ValueKind is not (JsonValueKind.True or JsonValueKind.False)
            || !residentElement.GetBoolean())
        {
            throw new CentralToolException("workspace_project_status after stop did not report a resident background editor.");
        }
    }

    private static void EnsureLifecycleCapabilityUnavailable(JsonElement payload, string toolName)
    {
        if (payload.ValueKind != JsonValueKind.Object)
        {
            throw new CentralToolException($"{toolName} did not return an object payload.");
        }

        if (!payload.TryGetProperty("editorLifecycle", out var lifecycle)
            || lifecycle.ValueKind != JsonValueKind.Object)
        {
            throw new CentralToolException($"{toolName} is missing editorLifecycle.");
        }

        if (!lifecycle.TryGetProperty("supportsEditorLifecycle", out var supportsElement)
            || supportsElement.ValueKind is not (JsonValueKind.True or JsonValueKind.False)
            || supportsElement.GetBoolean())
        {
            throw new CentralToolException($"{toolName} unexpectedly reported editor lifecycle support.");
        }

        if (!lifecycle.TryGetProperty("canGracefulClose", out var gracefulElement)
            || gracefulElement.ValueKind is not (JsonValueKind.True or JsonValueKind.False)
            || gracefulElement.GetBoolean())
        {
            throw new CentralToolException($"{toolName} unexpectedly reported graceful close availability.");
        }

        if (!payload.TryGetProperty("editorState", out var editorState)
            || editorState.ValueKind != JsonValueKind.Object)
        {
            throw new CentralToolException($"{toolName} is missing editorState.");
        }

        if (!editorState.TryGetProperty("error", out var errorElement)
            || errorElement.ValueKind != JsonValueKind.String
            || !string.Equals(errorElement.GetString(), "editor_lifecycle_unsupported", StringComparison.Ordinal))
        {
            throw new CentralToolException($"{toolName} did not expose editor_lifecycle_unsupported in editorState.");
        }
    }

    private static void EnsureLifecycleCapabilityAvailable(JsonElement payload, string toolName)
    {
        if (payload.ValueKind != JsonValueKind.Object)
        {
            throw new CentralToolException($"{toolName} did not return an object payload.");
        }

        if (!payload.TryGetProperty("editorLifecycle", out var lifecycle)
            || lifecycle.ValueKind != JsonValueKind.Object)
        {
            throw new CentralToolException($"{toolName} is missing editorLifecycle.");
        }

        if (!lifecycle.TryGetProperty("supportsEditorLifecycle", out var supportsElement)
            || supportsElement.ValueKind is not (JsonValueKind.True or JsonValueKind.False)
            || !supportsElement.GetBoolean())
        {
            throw new CentralToolException($"{toolName} did not report editor lifecycle support.");
        }

        if (!lifecycle.TryGetProperty("canGracefulClose", out var gracefulElement)
            || gracefulElement.ValueKind is not (JsonValueKind.True or JsonValueKind.False)
            || !gracefulElement.GetBoolean())
        {
            throw new CentralToolException($"{toolName} did not report graceful close availability.");
        }

        if (!payload.TryGetProperty("editorState", out var editorState)
            || editorState.ValueKind != JsonValueKind.Object)
        {
            throw new CentralToolException($"{toolName} is missing editorState.");
        }

        if (editorState.TryGetProperty("error", out var errorElement)
            && errorElement.ValueKind == JsonValueKind.String
            && string.Equals(errorElement.GetString(), "editor_lifecycle_unsupported", StringComparison.Ordinal))
        {
            throw new CentralToolException($"{toolName} still reported editor_lifecycle_unsupported after lifecycle capability attach.");
        }
    }

    private static void EnsureOpenEditorMissingExecutablePayload(
        JsonElement payload,
        string toolName,
        string expectedProjectId,
        string requestedExecutablePath,
        string expectedAttachHost,
        int expectedAttachPort)
    {
        if (payload.ValueKind != JsonValueKind.Object)
        {
            throw new CentralToolException($"{toolName} missing-executable payload is not an object.");
        }

        if (!payload.TryGetProperty("project", out var projectElement)
            || projectElement.ValueKind != JsonValueKind.Object
            || !projectElement.TryGetProperty("projectId", out var projectIdElement)
            || projectIdElement.ValueKind != JsonValueKind.String
            || !string.Equals(projectIdElement.GetString(), expectedProjectId, StringComparison.OrdinalIgnoreCase))
        {
            throw new CentralToolException($"{toolName} missing-executable payload did not preserve the expected project id.");
        }

        if (!payload.TryGetProperty("requestedExecutablePath", out var requestedExecutableElement)
            || requestedExecutableElement.ValueKind != JsonValueKind.String
            || !string.Equals(requestedExecutableElement.GetString(), requestedExecutablePath, StringComparison.OrdinalIgnoreCase))
        {
            throw new CentralToolException($"{toolName} missing-executable payload did not preserve the requested executable path.");
        }

        if (!payload.TryGetProperty("guidance", out var guidanceElement)
            || guidanceElement.ValueKind != JsonValueKind.Object)
        {
            throw new CentralToolException($"{toolName} missing-executable payload is missing guidance.");
        }

        if (!guidanceElement.TryGetProperty("askUserForGodotPath", out var askUserElement)
            || askUserElement.ValueKind is not (JsonValueKind.True or JsonValueKind.False)
            || !askUserElement.GetBoolean())
        {
            throw new CentralToolException($"{toolName} missing-executable guidance did not request a Godot path.");
        }

        if (!guidanceElement.TryGetProperty("configureWith", out var configureWithElement)
            || configureWithElement.ValueKind != JsonValueKind.Array)
        {
            throw new CentralToolException($"{toolName} missing-executable guidance is missing configureWith.");
        }

        var configureTools = configureWithElement.EnumerateArray()
            .Where(item => item.ValueKind == JsonValueKind.Object
                           && item.TryGetProperty("tool", out var toolElement)
                           && toolElement.ValueKind == JsonValueKind.String)
            .Select(item => item.GetProperty("tool").GetString() ?? string.Empty)
            .ToArray();
        if (!configureTools.Contains("workspace_project_set_godot_path", StringComparer.Ordinal)
            || !configureTools.Contains("workspace_godot_set_default_executable", StringComparer.Ordinal))
        {
            throw new CentralToolException($"{toolName} missing-executable guidance did not include the expected configuration tools.");
        }

        if (!payload.TryGetProperty("centralHostSession", out var centralHostSession)
            || centralHostSession.ValueKind != JsonValueKind.Object)
        {
            throw new CentralToolException($"{toolName} missing-executable payload is missing centralHostSession.");
        }

        if (!centralHostSession.TryGetProperty("attachHost", out var attachHostElement)
            || attachHostElement.ValueKind != JsonValueKind.String
            || !string.Equals(attachHostElement.GetString(), expectedAttachHost, StringComparison.OrdinalIgnoreCase))
        {
            throw new CentralToolException($"{toolName} missing-executable payload returned an unexpected attachHost.");
        }

        if (!centralHostSession.TryGetProperty("attachPort", out var attachPortElement)
            || attachPortElement.ValueKind != JsonValueKind.Number
            || !attachPortElement.TryGetInt32(out var attachPort)
            || attachPort != expectedAttachPort)
        {
            throw new CentralToolException($"{toolName} missing-executable payload returned an unexpected attachPort.");
        }

        if (!centralHostSession.TryGetProperty("editorLifecycle", out var lifecycle)
            || lifecycle.ValueKind != JsonValueKind.Object)
        {
            throw new CentralToolException($"{toolName} missing-executable payload is missing centralHostSession.editorLifecycle.");
        }

        if (!lifecycle.TryGetProperty("resolution", out var resolutionElement)
            || resolutionElement.ValueKind != JsonValueKind.String
            || !string.Equals(resolutionElement.GetString(), "godot_executable_not_found", StringComparison.Ordinal))
        {
            throw new CentralToolException($"{toolName} missing-executable payload did not expose resolution=godot_executable_not_found.");
        }
    }

    private static void EnsurePayloadSessionId(JsonElement payload, string toolName, string expectedSessionId)
    {
        var actualSessionId = ExtractPayloadSessionId(payload, toolName);
        if (!string.Equals(actualSessionId, expectedSessionId, StringComparison.OrdinalIgnoreCase))
        {
            throw new CentralToolException($"{toolName} returned unexpected sessionId '{actualSessionId}', expected '{expectedSessionId}'.");
        }
    }

    private static void EnsurePayloadSessionIdChanged(JsonElement payload, string toolName, string previousSessionId)
    {
        var actualSessionId = ExtractPayloadSessionId(payload, toolName);
        if (string.Equals(actualSessionId, previousSessionId, StringComparison.OrdinalIgnoreCase))
        {
            throw new CentralToolException($"{toolName} did not switch to a new session id.");
        }
    }

    private static string ExtractPayloadSessionId(JsonElement payload, string toolName)
    {
        if (payload.ValueKind != JsonValueKind.Object)
        {
            throw new CentralToolException($"{toolName} did not return an object payload.");
        }

        if (payload.TryGetProperty("editorSession", out var sessionElement)
            && sessionElement.ValueKind == JsonValueKind.Object
            && sessionElement.TryGetProperty("sessionId", out var sessionIdElement)
            && sessionIdElement.ValueKind == JsonValueKind.String)
        {
            return sessionIdElement.GetString() ?? string.Empty;
        }

        if (payload.TryGetProperty("editorLifecycle", out var lifecycleElement)
            && lifecycleElement.ValueKind == JsonValueKind.Object
            && lifecycleElement.TryGetProperty("sessionId", out var lifecycleSessionIdElement)
            && lifecycleSessionIdElement.ValueKind == JsonValueKind.String)
        {
            return lifecycleSessionIdElement.GetString() ?? string.Empty;
        }

        throw new CentralToolException($"{toolName} did not include a sessionId in editorSession or editorLifecycle.");
    }

    private static void EnsureLifecycleToolSessionReady(JsonElement payload, string toolName)
    {
        if (payload.ValueKind != JsonValueKind.Object)
        {
            throw new CentralToolException($"{toolName} did not return an object payload.");
        }

        var lifecycle = payload.TryGetProperty("editorLifecycle", out var directLifecycle)
                       && directLifecycle.ValueKind == JsonValueKind.Object
            ? directLifecycle
            : payload.TryGetProperty("centralHostSession", out var centralHostSession)
              && centralHostSession.ValueKind == JsonValueKind.Object
              && centralHostSession.TryGetProperty("editorLifecycle", out var nestedLifecycle)
              && nestedLifecycle.ValueKind == JsonValueKind.Object
                ? nestedLifecycle
                : default;
        if (lifecycle.ValueKind != JsonValueKind.Object)
        {
            throw new CentralToolException($"{toolName} is missing editorLifecycle.");
        }

        if (!lifecycle.TryGetProperty("attached", out var attachedElement)
            || attachedElement.ValueKind is not (JsonValueKind.True or JsonValueKind.False)
            || !attachedElement.GetBoolean())
        {
            throw new CentralToolException($"{toolName} did not report an attached editor session.");
        }

        if (!lifecycle.TryGetProperty("httpReady", out var readyElement)
            || readyElement.ValueKind is not (JsonValueKind.True or JsonValueKind.False)
            || !readyElement.GetBoolean())
        {
            throw new CentralToolException($"{toolName} did not report an HTTP-ready editor session.");
        }
    }

    private static void EnsureLifecycleToolClosed(JsonElement payload, string toolName)
    {
        if (payload.ValueKind != JsonValueKind.Object)
        {
            throw new CentralToolException($"{toolName} did not return an object payload.");
        }

        if (!payload.TryGetProperty("editorLifecycle", out var lifecycle)
            || lifecycle.ValueKind != JsonValueKind.Object)
        {
            throw new CentralToolException($"{toolName} is missing editorLifecycle.");
        }

        if (lifecycle.TryGetProperty("resident", out var residentElement)
            && residentElement.ValueKind is JsonValueKind.True or JsonValueKind.False
            && residentElement.GetBoolean())
        {
            throw new CentralToolException($"{toolName} still reported a resident editor.");
        }

        if (lifecycle.TryGetProperty("attached", out var attachedElement)
            && attachedElement.ValueKind is JsonValueKind.True or JsonValueKind.False
            && attachedElement.GetBoolean())
        {
            throw new CentralToolException($"{toolName} still reported an attached editor session.");
        }
    }

    private static void TrackLaunchFromPayload(JsonElement payload, ref int launchedProcessId, ref bool launchedAlreadyRunning)
    {
        TrackCurrentProcessFromPayload(payload, ref launchedProcessId);

        if (payload.ValueKind != JsonValueKind.Object)
        {
            return;
        }

        if (payload.TryGetProperty("centralHostSession", out var centralHostSession)
            && centralHostSession.ValueKind == JsonValueKind.Object)
        {
            if (centralHostSession.TryGetProperty("editorLifecycle", out var lifecycleElement)
                && lifecycleElement.ValueKind == JsonValueKind.Object)
            {
                if (lifecycleElement.TryGetProperty("resolution", out var resolutionElement)
                    && resolutionElement.ValueKind == JsonValueKind.String)
                {
                    launchedAlreadyRunning = !string.Equals(
                        resolutionElement.GetString(),
                        "launched_editor",
                        StringComparison.OrdinalIgnoreCase);
                }
            }
        }

        if (payload.TryGetProperty("launch", out var launchElement)
            && launchElement.ValueKind == JsonValueKind.Object)
        {
            if (launchElement.TryGetProperty("alreadyRunning", out var alreadyRunningElement)
                && alreadyRunningElement.ValueKind is JsonValueKind.True or JsonValueKind.False)
            {
                launchedAlreadyRunning = alreadyRunningElement.GetBoolean();
            }
        }
    }

    private static void TrackCurrentProcessFromPayload(JsonElement payload, ref int processId)
    {
        if (payload.ValueKind != JsonValueKind.Object)
        {
            return;
        }

        if (payload.TryGetProperty("centralHostSession", out var centralHostSession)
            && centralHostSession.ValueKind == JsonValueKind.Object
            && centralHostSession.TryGetProperty("editorLifecycle", out var lifecycleElement)
            && lifecycleElement.ValueKind == JsonValueKind.Object
            && lifecycleElement.TryGetProperty("processId", out var lifecycleProcessIdElement)
            && lifecycleProcessIdElement.ValueKind == JsonValueKind.Number)
        {
            processId = lifecycleProcessIdElement.GetInt32();
        }

        if (payload.TryGetProperty("launch", out var launchElement)
            && launchElement.ValueKind == JsonValueKind.Object
            && launchElement.TryGetProperty("processId", out var launchProcessIdElement)
            && launchProcessIdElement.ValueKind == JsonValueKind.Number)
        {
            processId = launchProcessIdElement.GetInt32();
        }

        if (payload.TryGetProperty("editorLifecycle", out var directLifecycle)
            && directLifecycle.ValueKind == JsonValueKind.Object
            && directLifecycle.TryGetProperty("processId", out var directProcessIdElement)
            && directProcessIdElement.ValueKind == JsonValueKind.Number)
        {
            processId = directProcessIdElement.GetInt32();
        }
    }

    private static void TryKillProcessTree(int processId)
    {
        try
        {
            using var process = Process.GetProcessById(processId);
            if (!process.HasExited)
            {
                process.Kill(entireProcessTree: true);
                process.WaitForExit(5_000);
            }
        }
        catch
        {
        }
    }

    private sealed record AutoLaunchProjectResolution(bool ShouldSkip, string? Message, string? ProjectRoot)
    {
        public static AutoLaunchProjectResolution FromProject(string projectRoot)
            => new(false, null, projectRoot);

        public static AutoLaunchProjectResolution Skip(string message, string? projectRoot)
            => new(true, message, projectRoot);
    }
}
