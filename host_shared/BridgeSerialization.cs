using System.Text;
using System.Text.Json;

namespace GodotDotnetMcp.HostShared;

internal static class BridgeSerialization
{
    internal static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        WriteIndented = false,
    };

    internal static string SerializeCompact<T>(T value)
    {
        return JsonSerializer.Serialize(value, JsonOptions);
    }

    internal static Task WriteJsonAsync<T>(Stream output, T payload, CancellationToken cancellationToken)
    {
        var json = JsonSerializer.Serialize(payload, JsonOptions);
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
}
