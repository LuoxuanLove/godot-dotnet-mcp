using System.Text;
using System.Text.Json;

namespace GodotDotnetMcp.DotnetBridge;

internal static class BridgeApplication
{
    public static async Task<int> RunAsync(string[] args, Stream input, Stream output, TextWriter error, CancellationToken cancellationToken = default)
    {
        var options = BridgeOptions.Parse(args);

        if (options.RemainingArguments.Length > 0)
        {
            await error.WriteLineAsync($"Unrecognized arguments: {string.Join(" ", options.RemainingArguments)}");
            await error.WriteLineAsync("Use --help for usage.");
            return 2;
        }

        return options.Mode switch
        {
            BridgeMode.Help => await PrintHelpAsync(error),
            BridgeMode.Version => await PrintVersionAsync(output, cancellationToken),
            BridgeMode.Health => await PrintHealthAsync(output, cancellationToken),
            _ => await RunStdioAsync(input, output, error, cancellationToken),
        };
    }

    private static Task<int> PrintHelpAsync(TextWriter error)
    {
        return error.WriteLineAsync("""
Godot .NET MCP Bridge

Usage:
  GodotDotnetMcp.DotnetBridge [--stdio]
  GodotDotnetMcp.DotnetBridge --health
  GodotDotnetMcp.DotnetBridge --version

Modes:
  --stdio     Start the MCP stdio server (default)
  --health    Print a JSON health snapshot and exit
  --version   Print the bridge version and exit
""").ContinueWith(_ => 0);
    }

    private static async Task<int> PrintVersionAsync(Stream output, CancellationToken cancellationToken)
    {
        await using var writer = new StreamWriter(output, new UTF8Encoding(encoderShouldEmitUTF8Identifier: false), leaveOpen: true);
        await writer.WriteLineAsync(BridgeManifest.Version.AsMemory(), cancellationToken);
        await writer.FlushAsync(cancellationToken);
        return 0;
    }

    private static async Task<int> PrintHealthAsync(Stream output, CancellationToken cancellationToken)
    {
        var payload = new BridgeHealthSnapshot(
            Status: "ok",
            Name: BridgeManifest.ProductName,
            Version: BridgeManifest.Version,
            TargetFramework: BridgeManifest.TargetFramework,
            Protocol: BridgeManifest.Protocol,
            TimestampUtc: DateTimeOffset.UtcNow);

        await WriteJsonAsync(output, payload, cancellationToken);
        return 0;
    }

    private static async Task<int> RunStdioAsync(Stream input, Stream output, TextWriter error, CancellationToken cancellationToken)
    {
        var server = new StdioMcpServer(output, error);
        await server.RunAsync(input, cancellationToken);
        return 0;
    }

    internal static Task WriteJsonAsync<T>(Stream output, T payload, CancellationToken cancellationToken)
    {
        var json = JsonSerializer.Serialize(payload, BridgeSerialization.JsonOptions);
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

    internal sealed record BridgeHealthSnapshot(
        string Status,
        string Name,
        string Version,
        string TargetFramework,
        string Protocol,
        DateTimeOffset TimestampUtc);
}
