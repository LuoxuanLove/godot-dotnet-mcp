using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Text.Json;

namespace GodotDotnetMcp.CentralServer;

internal static class SmokeHttpSupport
{
    public static async Task WaitForAttachServerReadyAsync(string host, int port, CancellationToken cancellationToken)
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

    public static async Task<JsonElement> SendJsonRequestAsync(
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

    public static async Task<IncomingHttpRequest> ReadIncomingRequestAsync(NetworkStream stream, CancellationToken cancellationToken)
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

    public static IPAddress ParseAddress(string host)
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
}

internal sealed class IncomingHttpRequest
{
    public string Method { get; set; } = string.Empty;

    public string Path { get; set; } = string.Empty;

    public byte[] Body { get; set; } = [];
}
