using System.Text.Json;
using static GodotDotnetMcp.CentralServer.SmokeAssertionSupport;
using static GodotDotnetMcp.CentralServer.SmokePayloadSupport;

namespace GodotDotnetMcp.CentralServer;

internal static partial class SmokeSystemSessionRunner
{
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
        CentralWorkspaceState workspaceState,
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
        var interruptEditorLifecycleCoordinator = new EditorLifecycleCoordinator(configuration, editorProcesses, interruptEditorProxy, editorSessionCoordinator, editorSessions, registry, workspaceState);
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
            workspaceState);
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
                activeProjectId = workspaceState.ActiveProjectId,
                activeEditorSessionId = workspaceState.ActiveEditorSessionId,
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
}
