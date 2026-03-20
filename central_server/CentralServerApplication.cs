using System.Text;
using System.Text.Json;

namespace GodotDotnetMcp.CentralServer;

internal static class CentralServerApplication
{
    public static async Task<int> RunAsync(string[] args, Stream input, Stream output, TextWriter error, CancellationToken cancellationToken = default)
    {
        try
        {
            var options = CentralServerOptions.Parse(args);

            if (RequiresNoExtraArguments(options.Mode) && options.RemainingArguments.Length > 0)
            {
                await error.WriteLineAsync($"Unrecognized arguments: {string.Join(" ", options.RemainingArguments)}");
                await error.WriteLineAsync("Use --help for usage.");
                return 2;
            }

            return options.Mode switch
            {
                CentralServerMode.Help => await PrintHelpAsync(error),
                CentralServerMode.Version => await PrintVersionAsync(output, cancellationToken),
                CentralServerMode.Health => await PrintHealthAsync(output, cancellationToken),
                CentralServerMode.AttachOnly => await RunAttachOnlyAsync(options.RemainingArguments, output, error, cancellationToken),
                CentralServerMode.ProxyCall => await RunProxyCallAsync(options.RemainingArguments, output, error, cancellationToken),
                _ => await RunStdioAsync(input, output, error, cancellationToken),
            };
        }
        catch (CentralToolException ex)
        {
            await error.WriteLineAsync(ex.Message);
            return 2;
        }
    }

    private static Task<int> PrintHelpAsync(TextWriter error)
    {
        return error.WriteLineAsync("""
Godot .NET MCP Central Server

Usage:
  GodotDotnetMcp.CentralServer [--stdio]
  GodotDotnetMcp.CentralServer --attach-only [--attach-host HOST] [--attach-port PORT]
  GodotDotnetMcp.CentralServer --proxy-call --tool TOOL [--server-host HOST] [--server-port PORT] [--args-json JSON] [--arg key=value]
  GodotDotnetMcp.CentralServer --health
  GodotDotnetMcp.CentralServer --version

Modes:
  --stdio        Start the MCP stdio server (default)
  --attach-only  Start only the local editor attach HTTP server and keep running
  --proxy-call   Forward one tool call directly to a Godot editor MCP HTTP endpoint
                 Use --arg key=value for simple arguments, or --args-json for a full JSON object
  --health       Print a JSON health snapshot and exit
  --version      Print the central server version and exit
""").ContinueWith(_ => 0);
    }

    private static async Task<int> PrintVersionAsync(Stream output, CancellationToken cancellationToken)
    {
        await using var writer = new StreamWriter(output, new UTF8Encoding(encoderShouldEmitUTF8Identifier: false), leaveOpen: true);
        await writer.WriteLineAsync(CentralServerManifest.Version.AsMemory(), cancellationToken);
        await writer.FlushAsync(cancellationToken);
        return 0;
    }

    private static async Task<int> PrintHealthAsync(Stream output, CancellationToken cancellationToken)
    {
        var payload = new CentralHealthSnapshot(
            Status: "ok",
            Name: CentralServerManifest.ProductName,
            Version: CentralServerManifest.Version,
            TargetFramework: CentralServerManifest.TargetFramework,
            Protocol: CentralServerManifest.Protocol,
            TimestampUtc: DateTimeOffset.UtcNow);

        var json = JsonSerializer.Serialize(payload, CentralServerSerialization.JsonOptions);
        await using var writer = new StreamWriter(output, new UTF8Encoding(encoderShouldEmitUTF8Identifier: false), leaveOpen: true);
        await writer.WriteAsync(json.AsMemory(), cancellationToken);
        await writer.WriteLineAsync();
        await writer.FlushAsync(cancellationToken);
        return 0;
    }

    private static async Task<int> RunStdioAsync(Stream input, Stream output, TextWriter error, CancellationToken cancellationToken)
    {
        var configuration = new CentralConfigurationService();
        var editorProcesses = new EditorProcessService();
        var godotInstallations = new GodotInstallationService();
        var godotProjectManager = new GodotProjectManagerProvider(configuration);
        godotProjectManager.StartWatcher();
        var registry = new ProjectRegistryService();
        var editorSessions = new EditorSessionService(registry);
        using var editorProxy = new EditorProxyService();
        var sessionState = new SessionState();
        var dispatcher = new CentralToolDispatcher(configuration, editorProxy, editorProcesses, editorSessions, godotInstallations, godotProjectManager, registry, sessionState);
        var server = new CentralStdioMcpServer(output, error, dispatcher);
        using var attachServerCts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        var attachEndpoint = ResolveAttachEndpoint(options: null, configuration);
        await using var attachServer = new EditorAttachHttpServer(attachEndpoint.Host, attachEndpoint.Port, editorSessions, error);
        attachServer.Start(attachServerCts.Token);
        try
        {
            await server.RunAsync(input, cancellationToken);
        }
        finally
        {
            attachServerCts.Cancel();
        }
        return 0;
    }

    private static async Task<int> RunAttachOnlyAsync(string[] args, Stream output, TextWriter error, CancellationToken cancellationToken)
    {
        var configuration = new CentralConfigurationService();
        var registry = new ProjectRegistryService();
        var editorSessions = new EditorSessionService(registry);
        var attachEndpoint = ResolveAttachEndpoint(args, configuration);

        await using var attachServer = new EditorAttachHttpServer(attachEndpoint.Host, attachEndpoint.Port, editorSessions, error);
        attachServer.Start(cancellationToken);

        await using var writer = new StreamWriter(output, new UTF8Encoding(encoderShouldEmitUTF8Identifier: false), leaveOpen: true);
        await writer.WriteLineAsync($"attach-only listening on http://{attachEndpoint.Host}:{attachEndpoint.Port}/");
        await writer.FlushAsync();

        try
        {
            await Task.Delay(Timeout.Infinite, cancellationToken);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
        }

        return 0;
    }

    private static async Task<int> RunProxyCallAsync(string[] args, Stream output, TextWriter error, CancellationToken cancellationToken)
    {
        var serverHost = GetOptionValue(args, "--server-host") ?? "127.0.0.1";
        var serverPort = ParseIntOption(args, "--server-port", 3000);
        var toolName = GetOptionValue(args, "--tool");
        if (string.IsNullOrWhiteSpace(toolName))
        {
            await error.WriteLineAsync("Missing required option --tool for --proxy-call.");
            return 2;
        }

        JsonElement toolArguments;
        try
        {
            toolArguments = ParseProxyToolArguments(args);
        }
        catch (JsonException ex)
        {
            await error.WriteLineAsync($"Invalid --args-json payload: {ex.Message}");
            return 2;
        }

        using var editorProxy = new EditorProxyService();
        var forwarded = await editorProxy.ForwardToolCallToEndpointAsync(serverHost, serverPort, toolName, toolArguments, cancellationToken);
        var payload = new
        {
            success = forwarded.Success,
            endpoint = forwarded.Endpoint,
            toolName,
            arguments = toolArguments,
            result = forwarded.ToolResult,
            message = forwarded.Message,
        };

        await using var writer = new StreamWriter(output, new UTF8Encoding(encoderShouldEmitUTF8Identifier: false), leaveOpen: true);
        await writer.WriteLineAsync(JsonSerializer.Serialize(payload, CentralServerSerialization.JsonOptions));
        await writer.FlushAsync();
        return forwarded.Success ? 0 : 1;
    }

    private static bool RequiresNoExtraArguments(CentralServerMode mode)
    {
        return mode is CentralServerMode.Stdio
            or CentralServerMode.Health
            or CentralServerMode.Version
            or CentralServerMode.Help;
    }

    private static AttachEndpoint ResolveAttachEndpoint(string[]? options, CentralConfigurationService configuration)
    {
        var host = GetOptionValue(options, "--attach-host") ?? configuration.EditorAttachHost;
        var port = ParseIntOption(options, "--attach-port", configuration.EditorAttachPort);
        return new AttachEndpoint(host, port);
    }

    private static string? GetOptionValue(string[]? args, string optionName)
    {
        if (args is null || args.Length == 0)
        {
            return null;
        }

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

    private static string[] GetOptionValues(string[]? args, string optionName)
    {
        if (args is null || args.Length == 0)
        {
            return [];
        }

        var values = new List<string>();
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

            values.Add(args[index + 1]);
        }

        return values.ToArray();
    }

    private static int ParseIntOption(string[]? args, string optionName, int defaultValue)
    {
        var value = GetOptionValue(args, optionName);
        if (string.IsNullOrWhiteSpace(value))
        {
            return defaultValue;
        }

        if (!int.TryParse(value, out var parsed) || parsed <= 0)
        {
            throw new CentralToolException($"Option {optionName} must be a positive integer.");
        }

        return parsed;
    }

    private static JsonElement ParseProxyToolArguments(string[] args)
    {
        var argsJson = GetOptionValue(args, "--args-json");
        if (!string.IsNullOrWhiteSpace(argsJson))
        {
            using var document = JsonDocument.Parse(argsJson);
            if (document.RootElement.ValueKind != JsonValueKind.Object)
            {
                throw new CentralToolException("--args-json must be a JSON object.");
            }

            return document.RootElement.Clone();
        }

        var argPairs = GetOptionValues(args, "--arg");
        if (argPairs.Length == 0)
        {
            return JsonSerializer.SerializeToElement(new Dictionary<string, object?>(), CentralServerSerialization.JsonOptions);
        }

        var payload = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
        foreach (var pair in argPairs)
        {
            var separatorIndex = pair.IndexOf('=');
            if (separatorIndex <= 0 || separatorIndex == pair.Length - 1)
            {
                throw new CentralToolException("--arg expects key=value.");
            }

            var key = pair[..separatorIndex].Trim();
            var rawValue = pair[(separatorIndex + 1)..].Trim();
            if (string.IsNullOrWhiteSpace(key))
            {
                throw new CentralToolException("--arg key cannot be empty.");
            }

            payload[key] = ParseScalarArgument(rawValue);
        }

        return JsonSerializer.SerializeToElement(payload, CentralServerSerialization.JsonOptions);
    }

    private static object? ParseScalarArgument(string rawValue)
    {
        if (bool.TryParse(rawValue, out var boolValue))
        {
            return boolValue;
        }

        if (int.TryParse(rawValue, out var intValue))
        {
            return intValue;
        }

        if (long.TryParse(rawValue, out var longValue))
        {
            return longValue;
        }

        if (double.TryParse(rawValue, out var doubleValue))
        {
            return doubleValue;
        }

        if (string.Equals(rawValue, "null", StringComparison.OrdinalIgnoreCase))
        {
            return null;
        }

        return rawValue;
    }

    internal static Task WriteJsonAsync<T>(Stream output, T payload, CancellationToken cancellationToken)
    {
        var json = JsonSerializer.Serialize(payload, CentralServerSerialization.JsonOptions);
        var body = Encoding.UTF8.GetBytes(json);
        var header = Encoding.ASCII.GetBytes($"Content-Length: {body.Length}\r\n\r\n");

        return WriteFramedMessageAsync(output, header, body, cancellationToken);
    }

    internal static async Task WriteFramedMessageAsync(Stream output, byte[] header, byte[] body, CancellationToken cancellationToken)
    {
        await output.WriteAsync(header, cancellationToken);
        await output.WriteAsync(body, cancellationToken);
        await output.FlushAsync(cancellationToken);
    }

    internal sealed record CentralHealthSnapshot(
        string Status,
        string Name,
        string Version,
        string TargetFramework,
        string Protocol,
        DateTimeOffset TimestampUtc);

    private sealed record AttachEndpoint(string Host, int Port);
}
