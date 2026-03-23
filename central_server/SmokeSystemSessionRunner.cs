using System.Diagnostics;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Text.Json;

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
        var dispatcher = new CentralToolDispatcher(configuration, editorProxy, editorProcesses, editorSessionCoordinator, editorSessions, godotInstallations, godotProjectManager, registry, sessionState);
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
                    dispatcher,
                    godotInstallations,
                    registry,
                    sessionState,
                    projectRootOption,
                    explicitGodotExecutablePath,
                    attachTimeoutMs,
                    requireAutoLaunch)
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

            await using var mockServer = new MockEditorMcpServer("127.0.0.1", mockPort);
            mockServer.Start(cancellationToken);

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

            var attachResponse = await SendJsonRequestAsync(
                attachHost,
                attachPort,
                "POST",
                "/api/editor/attach",
                new EditorSessionService.EditorSessionAttachRequest
                {
                    ProjectId = attachedProjectId,
                    ProjectRoot = projectRoot,
                    SessionId = "smoke-session",
                    PluginVersion = "smoke",
                    GodotVersion = "smoke",
                    Capabilities = ["system_project_state"],
                    TransportMode = "http",
                    ServerHost = "127.0.0.1",
                    ServerPort = mockPort,
                    ServerRunning = true,
                },
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

            var sessionId = centralHostSession.GetProperty("sessionId").GetString() ?? string.Empty;
            if (!string.Equals(sessionId, "smoke-session", StringComparison.OrdinalIgnoreCase))
            {
                throw new CentralToolException("system_project_state returned an unexpected sessionId.");
            }

            var resolution = centralHostSession.GetProperty("resolution").GetString() ?? string.Empty;
            if (!string.Equals(resolution, "reused_ready_session", StringComparison.OrdinalIgnoreCase))
            {
                throw new CentralToolException($"Unexpected centralHostSession.resolution: {resolution}");
            }

            var statusResponse = await dispatcher.ExecuteAsync(
                "workspace_project_status",
                SerializeToElement(new { projectId = attachedProjectId }),
                cancellationToken);
            EnsureSuccess(statusResponse, "workspace_project_status");

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
                projectId = centralHostSession.GetProperty("projectId").GetString(),
                projectPath = centralHostSession.GetProperty("projectPath").GetString(),
                sessionId,
                resolution,
                endpoint = centralHostSession.GetProperty("endpoint").GetString(),
                centralHostSession = DeserializeToObject(centralHostSession),
                systemResult = DeserializeToObject(systemPayload),
                workspaceStatus = DeserializeToObject(SerializeToElement(statusResponse.StructuredContent)),
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
        CentralToolDispatcher dispatcher,
        GodotInstallationService godotInstallations,
        ProjectRegistryService registry,
        SessionState sessionState,
        string? projectRootOption,
        string? explicitGodotExecutablePath,
        int attachTimeoutMs,
        bool requireAutoLaunch)
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
        var executablePath = string.Empty;
        var executableSource = string.Empty;
        var systemPayload = default(JsonElement);

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

            var resolution = centralHostSession.GetProperty("resolution").GetString() ?? string.Empty;
            if (!IsExpectedAutoLaunchResolution(resolution))
            {
                throw new CentralToolException($"Unexpected centralHostSession.resolution: {resolution}");
            }

            if (centralHostSession.TryGetProperty("launchProcessId", out var launchProcessIdElement)
                && launchProcessIdElement.ValueKind == JsonValueKind.Number)
            {
                launchedProcessId = launchProcessIdElement.GetInt32();
            }

            if (centralHostSession.TryGetProperty("launchAlreadyRunning", out var launchAlreadyRunningElement)
                && launchAlreadyRunningElement.ValueKind is JsonValueKind.True or JsonValueKind.False)
            {
                launchedAlreadyRunning = launchAlreadyRunningElement.GetBoolean();
            }

            var statusResponse = await dispatcher.ExecuteAsync(
                "workspace_project_status",
                SerializeToElement(new { projectId }),
                cancellationToken);
            EnsureSuccess(statusResponse, "workspace_project_status");

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
                launchedProcessId,
                launchedAlreadyRunning,
                activeProjectId = sessionState.ActiveProjectId,
                activeEditorSessionId = sessionState.ActiveEditorSessionId,
                systemPayload = systemPayload.ValueKind == JsonValueKind.Undefined
                    ? null
                    : DeserializeToObject(systemPayload),
            }, cancellationToken);
            await error.WriteLineAsync($"[CentralServerSmoke] {ex.Message}");
            await error.FlushAsync();
            return 1;
        }
        finally
        {
            if (launchedProcessId > 0 && !launchedAlreadyRunning)
            {
                TryKillProcessTree(launchedProcessId);
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
            else if (!string.IsNullOrWhiteSpace(cleanupProjectId))
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

    private static void TrackLaunchFromPayload(JsonElement payload, ref int launchedProcessId, ref bool launchedAlreadyRunning)
    {
        if (payload.ValueKind != JsonValueKind.Object)
        {
            return;
        }

        if (payload.TryGetProperty("centralHostSession", out var centralHostSession)
            && centralHostSession.ValueKind == JsonValueKind.Object)
        {
            if (centralHostSession.TryGetProperty("launchProcessId", out var processIdElement)
                && processIdElement.ValueKind == JsonValueKind.Number)
            {
                launchedProcessId = processIdElement.GetInt32();
            }

            if (centralHostSession.TryGetProperty("launchAlreadyRunning", out var alreadyRunningElement)
                && alreadyRunningElement.ValueKind is JsonValueKind.True or JsonValueKind.False)
            {
                launchedAlreadyRunning = alreadyRunningElement.GetBoolean();
            }
        }

        if (payload.TryGetProperty("launch", out var launchElement)
            && launchElement.ValueKind == JsonValueKind.Object)
        {
            if (launchElement.TryGetProperty("processId", out var processIdElement)
                && processIdElement.ValueKind == JsonValueKind.Number)
            {
                launchedProcessId = processIdElement.GetInt32();
            }

            if (launchElement.TryGetProperty("alreadyRunning", out var alreadyRunningElement)
                && alreadyRunningElement.ValueKind is JsonValueKind.True or JsonValueKind.False)
            {
                launchedAlreadyRunning = alreadyRunningElement.GetBoolean();
            }
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

    private static void EnsureSuccess(CentralToolCallResponse response, string toolName)
    {
        if (response.IsError)
        {
            throw new CentralToolException($"{toolName} failed during smoke test: {response.TextContent}");
        }
    }

    private static JsonElement SerializeToElement(object value)
    {
        return JsonSerializer.SerializeToElement(value, CentralServerSerialization.JsonOptions);
    }

    private static object? DeserializeToObject(JsonElement value)
    {
        return JsonSerializer.Deserialize<object>(value.GetRawText(), CentralServerSerialization.JsonOptions);
    }

    private static async Task WritePlainJsonAsync<T>(Stream output, T payload, CancellationToken cancellationToken)
    {
        var json = JsonSerializer.Serialize(payload, CentralServerSerialization.JsonOptions);
        await using var writer = new StreamWriter(output, new UTF8Encoding(encoderShouldEmitUTF8Identifier: false), leaveOpen: true);
        await writer.WriteAsync(json.AsMemory(), cancellationToken);
        await writer.WriteLineAsync();
        await writer.FlushAsync(cancellationToken);
    }

    private static int GetFreeTcpPort()
    {
        var listener = new TcpListener(IPAddress.Loopback, 0);
        listener.Start();
        try
        {
            return ((IPEndPoint)listener.LocalEndpoint).Port;
        }
        finally
        {
            listener.Stop();
        }
    }

    private static string? GetOptionValue(string[] args, string optionName)
    {
        for (var index = 0; index < args.Length; index++)
        {
            if (!string.Equals(args[index], optionName, StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }

            if (index + 1 >= args.Length)
            {
                throw new CentralToolException($"Missing value for option {optionName}.");
            }

            return args[index + 1];
        }

        return null;
    }

    private static bool HasOption(string[] args, string optionName)
    {
        return args.Any(arg => string.Equals(arg, optionName, StringComparison.OrdinalIgnoreCase));
    }

    private static int? ParsePositiveIntOption(string[] args, string optionName)
    {
        var raw = GetOptionValue(args, optionName);
        if (string.IsNullOrWhiteSpace(raw))
        {
            return null;
        }

        if (!int.TryParse(raw, out var value) || value <= 0)
        {
            throw new CentralToolException($"Option {optionName} must be a positive integer.");
        }

        return value;
    }

    private static async Task WaitForAttachServerReadyAsync(string host, int port, CancellationToken cancellationToken)
    {
        for (var attempt = 0; attempt < 30; attempt++)
        {
            cancellationToken.ThrowIfCancellationRequested();
            try
            {
                var response = await SendJsonRequestAsync(host, port, "GET", "/api/server/health", null, cancellationToken);
                if (response.TryGetProperty("success", out var successElement) && successElement.ValueKind == JsonValueKind.True)
                {
                    return;
                }
            }
            catch
            {
            }

            await Task.Delay(100, cancellationToken);
        }

        throw new CentralToolException("Attach server did not become healthy before the smoke test attach step.");
    }

    private static async Task<JsonElement> SendJsonRequestAsync(
        string host,
        int port,
        string method,
        string path,
        object? body,
        CancellationToken cancellationToken)
    {
        using var client = new TcpClient();
        await client.ConnectAsync(host, port, cancellationToken);
        await using var stream = client.GetStream();

        byte[] bodyBytes = [];
        if (body is not null)
        {
            var bodyJson = JsonSerializer.Serialize(body, CentralServerSerialization.JsonOptions);
            bodyBytes = Encoding.UTF8.GetBytes(bodyJson);
        }

        var requestBuilder = new StringBuilder()
            .Append(method)
            .Append(' ')
            .Append(path)
            .Append(" HTTP/1.1\r\n")
            .Append("Host: ")
            .Append(host)
            .Append(':')
            .Append(port)
            .Append("\r\nConnection: close\r\n");

        if (bodyBytes.Length > 0)
        {
            requestBuilder
                .Append("Content-Type: application/json\r\n")
                .Append("Content-Length: ")
                .Append(bodyBytes.Length)
                .Append("\r\n");
        }

        requestBuilder.Append("\r\n");
        var headerBytes = Encoding.ASCII.GetBytes(requestBuilder.ToString());
        await stream.WriteAsync(headerBytes, cancellationToken);
        if (bodyBytes.Length > 0)
        {
            await stream.WriteAsync(bodyBytes, cancellationToken);
        }

        await stream.FlushAsync(cancellationToken);

        var header = await ReadHttpHeadersAsync(stream, cancellationToken);
        var statusCode = ParseStatusCode(header);
        var contentLength = ParseContentLength(header);
        var responseBody = contentLength > 0
            ? await ReadExactAsync(stream, contentLength, cancellationToken)
            : [];

        if (statusCode < 200 || statusCode >= 300)
        {
            throw new CentralToolException($"HTTP request {method} {path} failed with status {statusCode}.");
        }

        if (responseBody.Length == 0)
        {
            return JsonDocument.Parse("{}").RootElement.Clone();
        }

        return JsonDocument.Parse(responseBody).RootElement.Clone();
    }

    private static async Task<string> ReadHttpHeadersAsync(NetworkStream stream, CancellationToken cancellationToken)
    {
        var buffer = new List<byte>(256);
        var recent = new Queue<byte>(4);
        var singleByte = new byte[1];

        while (true)
        {
            var read = await stream.ReadAsync(singleByte.AsMemory(0, 1), cancellationToken);
            if (read == 0)
            {
                throw new CentralToolException("Unexpected end of stream while reading HTTP response headers.");
            }

            var current = singleByte[0];
            buffer.Add(current);
            recent.Enqueue(current);
            if (recent.Count > 4)
            {
                recent.Dequeue();
            }

            if (recent.Count == 4
                && recent.ElementAt(0) == '\r'
                && recent.ElementAt(1) == '\n'
                && recent.ElementAt(2) == '\r'
                && recent.ElementAt(3) == '\n')
            {
                return Encoding.ASCII.GetString(buffer.ToArray());
            }
        }
    }

    private static int ParseStatusCode(string header)
    {
        var firstLine = header.Split("\r\n", StringSplitOptions.None).FirstOrDefault() ?? string.Empty;
        var parts = firstLine.Split(' ', StringSplitOptions.RemoveEmptyEntries);
        return parts.Length >= 2 && int.TryParse(parts[1], out var statusCode)
            ? statusCode
            : throw new CentralToolException("Malformed HTTP status line in smoke response.");
    }

    private static int ParseContentLength(string header)
    {
        foreach (var line in header.Split("\r\n", StringSplitOptions.RemoveEmptyEntries))
        {
            if (!line.StartsWith("Content-Length:", StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }

            var rawValue = line["Content-Length:".Length..].Trim();
            if (int.TryParse(rawValue, out var contentLength) && contentLength >= 0)
            {
                return contentLength;
            }
        }

        return 0;
    }

    private static async Task<byte[]> ReadExactAsync(NetworkStream stream, int length, CancellationToken cancellationToken)
    {
        var buffer = new byte[length];
        var offset = 0;
        while (offset < length)
        {
            var read = await stream.ReadAsync(buffer.AsMemory(offset, length - offset), cancellationToken);
            if (read == 0)
            {
                throw new CentralToolException("Unexpected end of stream while reading HTTP response body.");
            }

            offset += read;
        }

        return buffer;
    }

    private static async Task<IncomingHttpRequest> ReadIncomingRequestAsync(NetworkStream stream, CancellationToken cancellationToken)
    {
        var header = await ReadHttpHeadersAsync(stream, cancellationToken);
        var lines = header.Split("\r\n", StringSplitOptions.None);
        if (lines.Length == 0 || string.IsNullOrWhiteSpace(lines[0]))
        {
            throw new CentralToolException("Mock MCP request line is missing.");
        }

        var requestLine = lines[0].Split(' ', StringSplitOptions.RemoveEmptyEntries);
        if (requestLine.Length < 2)
        {
            throw new CentralToolException("Mock MCP request line is malformed.");
        }

        byte[] body;
        if (HasChunkedTransferEncoding(header))
        {
            body = await ReadChunkedBodyAsync(stream, cancellationToken);
        }
        else
        {
            var contentLength = ParseContentLength(header);
            body = contentLength > 0
                ? await ReadExactAsync(stream, contentLength, cancellationToken)
                : [];
        }

        return new IncomingHttpRequest
        {
            Method = requestLine[0],
            Path = requestLine[1],
            Body = body,
        };
    }

    private static bool HasChunkedTransferEncoding(string header)
    {
        foreach (var line in header.Split("\r\n", StringSplitOptions.RemoveEmptyEntries))
        {
            if (!line.StartsWith("Transfer-Encoding:", StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }

            var rawValue = line["Transfer-Encoding:".Length..].Trim();
            if (rawValue.Contains("chunked", StringComparison.OrdinalIgnoreCase))
            {
                return true;
            }
        }

        return false;
    }

    private static async Task<byte[]> ReadChunkedBodyAsync(NetworkStream stream, CancellationToken cancellationToken)
    {
        using var bodyStream = new MemoryStream();
        while (true)
        {
            var sizeLine = await ReadAsciiLineAsync(stream, cancellationToken);
            var sizeToken = sizeLine.Split(';', 2)[0].Trim();
            if (!int.TryParse(sizeToken, System.Globalization.NumberStyles.HexNumber, null, out var chunkSize) || chunkSize < 0)
            {
                throw new CentralToolException("Mock MCP request used an invalid chunk size.");
            }

            if (chunkSize == 0)
            {
                await ReadAsciiLineAsync(stream, cancellationToken);
                break;
            }

            var chunk = await ReadExactAsync(stream, chunkSize, cancellationToken);
            await bodyStream.WriteAsync(chunk, cancellationToken);
            await ReadExactAsync(stream, 2, cancellationToken);
        }

        return bodyStream.ToArray();
    }

    private static async Task<string> ReadAsciiLineAsync(NetworkStream stream, CancellationToken cancellationToken)
    {
        var buffer = new List<byte>(64);
        var singleByte = new byte[1];

        while (true)
        {
            var read = await stream.ReadAsync(singleByte.AsMemory(0, 1), cancellationToken);
            if (read == 0)
            {
                throw new CentralToolException("Unexpected end of stream while reading a chunked HTTP line.");
            }

            var current = singleByte[0];
            if (current == '\n')
            {
                if (buffer.Count > 0 && buffer[^1] == '\r')
                {
                    buffer.RemoveAt(buffer.Count - 1);
                }

                return Encoding.ASCII.GetString(buffer.ToArray());
            }

            buffer.Add(current);
        }
    }

    private sealed record AutoLaunchProjectResolution(bool ShouldSkip, string? Message, string? ProjectRoot)
    {
        public static AutoLaunchProjectResolution FromProject(string projectRoot)
            => new(false, null, projectRoot);

        public static AutoLaunchProjectResolution Skip(string message, string? projectRoot)
            => new(true, message, projectRoot);
    }

    private sealed class MockEditorMcpServer : IAsyncDisposable
    {
        private readonly TcpListener _listener;
        private Task? _serverTask;

        public MockEditorMcpServer(string host, int port)
        {
            _listener = new TcpListener(ParseAddress(host), port);
        }

        public string? LastRequestPayload { get; private set; }

        public void Start(CancellationToken cancellationToken)
        {
            _listener.Start();
            _serverTask = Task.Run(() => ServeOnceAsync(cancellationToken), cancellationToken);
        }

        private async Task ServeOnceAsync(CancellationToken cancellationToken)
        {
            try
            {
                using var client = await _listener.AcceptTcpClientAsync(cancellationToken);
                await using var stream = client.GetStream();
                var request = await ReadIncomingRequestAsync(stream, cancellationToken);
                LastRequestPayload = request.Body.Length == 0
                    ? string.Empty
                    : Encoding.UTF8.GetString(request.Body);

                string toolName = "unknown";
                object? forwardedArguments = null;
                if (!string.IsNullOrWhiteSpace(LastRequestPayload))
                {
                    using var document = JsonDocument.Parse(LastRequestPayload);
                    if (document.RootElement.TryGetProperty("params", out var paramsElement))
                    {
                        if (paramsElement.TryGetProperty("name", out var nameElement) && nameElement.ValueKind == JsonValueKind.String)
                        {
                            toolName = nameElement.GetString() ?? toolName;
                        }

                        if (paramsElement.TryGetProperty("arguments", out var argumentsElement))
                        {
                            forwardedArguments = DeserializeToObject(argumentsElement.Clone());
                        }
                    }
                }

                var payloadText = JsonSerializer.Serialize(new
                {
                    mockForwarded = true,
                    toolName,
                    echoArguments = forwardedArguments,
                }, CentralServerSerialization.JsonOptions);

                var responseText = JsonSerializer.Serialize(new
                {
                    jsonrpc = "2.0",
                    id = "mock-response",
                    result = new
                    {
                        content = new[]
                        {
                            new
                            {
                                type = "text",
                                text = payloadText,
                            }
                        },
                        isError = false,
                    },
                }, CentralServerSerialization.JsonOptions);

                var bytes = Encoding.UTF8.GetBytes(responseText);
                var header = Encoding.ASCII.GetBytes(
                    "HTTP/1.1 200 OK\r\n" +
                    "Content-Type: application/json; charset=utf-8\r\n" +
                    $"Content-Length: {bytes.Length}\r\n" +
                    "Connection: close\r\n\r\n");

                await stream.WriteAsync(header, cancellationToken);
                await stream.WriteAsync(bytes, cancellationToken);
                await stream.FlushAsync(cancellationToken);
            }
            catch when (cancellationToken.IsCancellationRequested)
            {
            }
            catch (ObjectDisposedException)
            {
            }
            catch (SocketException)
            {
            }
        }

        public async ValueTask DisposeAsync()
        {
            try
            {
                _listener.Stop();
            }
            catch
            {
            }

            if (_serverTask is not null)
            {
                try
                {
                    await _serverTask;
                }
                catch
                {
                }
            }
        }
    }

    private sealed class IncomingHttpRequest
    {
        public string Method { get; set; } = string.Empty;

        public string Path { get; set; } = string.Empty;

        public byte[] Body { get; set; } = [];
    }

    private static IPAddress ParseAddress(string host)
    {
        if (string.Equals(host, "localhost", StringComparison.OrdinalIgnoreCase))
        {
            return IPAddress.Loopback;
        }

        if (IPAddress.TryParse(host, out var address))
        {
            return address;
        }

        return Dns.GetHostAddresses(host)
            .FirstOrDefault(address => address.AddressFamily == AddressFamily.InterNetwork)
               ?? IPAddress.Loopback;
    }
}
