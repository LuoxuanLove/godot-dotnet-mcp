using System.Text;
using System.Text.Json;
using static GodotDotnetMcp.CentralServer.SmokeAssertionSupport;
using static GodotDotnetMcp.CentralServer.SmokeHttpSupport;
using static GodotDotnetMcp.CentralServer.SmokePayloadSupport;

namespace GodotDotnetMcp.CentralServer;

internal static partial class SmokeSystemSessionRunner
{
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
}
