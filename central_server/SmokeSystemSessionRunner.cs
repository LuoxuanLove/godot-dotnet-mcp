using System.Diagnostics;
using System.Net;
using System.Net.Sockets;
using System.Text.Json;
using static GodotDotnetMcp.CentralServer.SmokeAssertionSupport;
using static GodotDotnetMcp.CentralServer.SmokeHttpSupport;
using static GodotDotnetMcp.CentralServer.SmokePayloadSupport;

namespace GodotDotnetMcp.CentralServer;

internal static partial class SmokeSystemSessionRunner
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
