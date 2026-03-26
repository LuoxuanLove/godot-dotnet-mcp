using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Text.Json;

namespace GodotDotnetMcp.CentralServer;

internal static class SmokePayloadSupport
{
    public static string TrySerializeForDiagnostic(object? value)
    {
        if (value is null)
        {
            return "null";
        }

        try
        {
            var text = CentralServerSerialization.SerializeCompact(value);
            return text.Length <= 4_000 ? text : $"{text[..4_000]}...(truncated)";
        }
        catch
        {
            return value.ToString() ?? "<unserializable>";
        }
    }

    public static JsonElement SerializeToElement(object value)
    {
        return JsonSerializer.SerializeToElement(value, CentralServerSerialization.JsonOptions);
    }

    public static object? DeserializeToObject(JsonElement value)
    {
        return JsonSerializer.Deserialize<object>(value.GetRawText(), CentralServerSerialization.JsonOptions);
    }

    public static EditorSessionService.EditorSessionAttachRequest BuildMockAttachRequest(
        string projectId,
        string projectRoot,
        string sessionId,
        string[] capabilities,
        int mockPort)
    {
        return new EditorSessionService.EditorSessionAttachRequest
        {
            ProjectId = projectId,
            ProjectRoot = projectRoot,
            SessionId = sessionId,
            PluginVersion = "smoke",
            GodotVersion = "smoke",
            Capabilities = capabilities,
            TransportMode = "http",
            ServerHost = "127.0.0.1",
            ServerPort = mockPort,
            ServerRunning = true,
        };
    }

    public static async Task WritePlainJsonAsync<T>(Stream output, T payload, CancellationToken cancellationToken)
    {
        var json = JsonSerializer.Serialize(payload, CentralServerSerialization.JsonOptions);
        await using var writer = new StreamWriter(output, new UTF8Encoding(encoderShouldEmitUTF8Identifier: false), leaveOpen: true);
        await writer.WriteAsync(json.AsMemory(), cancellationToken);
        await writer.WriteLineAsync();
        await writer.FlushAsync(cancellationToken);
    }

    public static int GetFreeTcpPort()
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

    public static string? GetOptionValue(string[] args, string optionName)
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

    public static bool HasOption(string[] args, string optionName)
    {
        return args.Any(arg => string.Equals(arg, optionName, StringComparison.OrdinalIgnoreCase));
    }

    public static int? ParsePositiveIntOption(string[] args, string optionName)
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
}
