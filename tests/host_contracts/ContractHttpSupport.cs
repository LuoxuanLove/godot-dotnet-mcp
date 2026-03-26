using System.Net.Sockets;
using System.Text;
using System.Text.Json;
using GodotDotnetMcp.CentralServer;

internal static class ContractHttpSupport
{
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
            : throw new CentralToolException("Malformed HTTP status line in contract response.");
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
}
