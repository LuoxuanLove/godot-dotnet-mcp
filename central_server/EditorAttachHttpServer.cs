using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Text.Json;

namespace GodotDotnetMcp.CentralServer;

internal sealed class EditorAttachHttpServer : IAsyncDisposable
{
    private readonly TextWriter _error;
    private readonly EditorSessionService _sessions;
    private readonly TcpListener _listener;
    private readonly string _prefix;
    private readonly Func<Task>? _shutdownRequested;
    private Task? _loopTask;

    public EditorAttachHttpServer(string host, int port, EditorSessionService sessions, TextWriter error, Func<Task>? shutdownRequested = null)
    {
        _sessions = sessions;
        _error = error;
        _listener = new TcpListener(ParseAddress(host), port);
        _prefix = $"http://{host}:{port}/";
        _shutdownRequested = shutdownRequested;
    }

    public string Prefix => _prefix;

    public void Start(CancellationToken cancellationToken)
    {
        _listener.Start();
        _loopTask = Task.Run(() => RunLoopAsync(cancellationToken), cancellationToken);
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

        if (_loopTask is not null)
        {
            try
            {
                await _loopTask;
            }
            catch
            {
            }
        }
    }

    private async Task RunLoopAsync(CancellationToken cancellationToken)
    {
        while (!cancellationToken.IsCancellationRequested)
        {
            TcpClient? client = null;
            try
            {
                client = await _listener.AcceptTcpClientAsync(cancellationToken);
            }
            catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
            {
                break;
            }
            catch (ObjectDisposedException) when (cancellationToken.IsCancellationRequested)
            {
                break;
            }
            catch (SocketException) when (cancellationToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception ex)
            {
                await _error.WriteLineAsync($"[CentralServer] Editor attach listener failed: {ex.Message}");
                continue;
            }

            _ = Task.Run(() => HandleClientAsync(client, cancellationToken), cancellationToken);
        }
    }

    private async Task HandleClientAsync(TcpClient client, CancellationToken cancellationToken)
    {
        using var _ = client;
        using var stream = client.GetStream();

        try
        {
            var request = await ReadRequestAsync(stream, cancellationToken);
            if (!string.Equals(request.Method, "POST", StringComparison.OrdinalIgnoreCase))
            {
                if (string.Equals(request.Method, "GET", StringComparison.OrdinalIgnoreCase)
                    && string.Equals(request.Path, "/api/server/health", StringComparison.OrdinalIgnoreCase))
                {
                    await WriteJsonResponseAsync(stream, 200, new { success = true, status = "ok", endpoint = _prefix }, cancellationToken);
                    return;
                }

                await WriteJsonResponseAsync(stream, 405, new { success = false, error = "Method not allowed" }, cancellationToken);
                return;
            }

            switch (request.Path)
            {
                case "/api/editor/attach":
                    await HandleAttachAsync(stream, request.Body, cancellationToken);
                    return;
                case "/api/editor/heartbeat":
                    await HandleHeartbeatAsync(stream, request.Body, cancellationToken);
                    return;
                case "/api/editor/detach":
                    await HandleDetachAsync(stream, request.Body, cancellationToken);
                    return;
                case "/api/server/shutdown":
                    await HandleShutdownAsync(stream, cancellationToken);
                    return;
                default:
                    await WriteJsonResponseAsync(stream, 404, new { success = false, error = "Not found", path = request.Path }, cancellationToken);
                    return;
            }
        }
        catch (CentralToolException ex)
        {
            await WriteJsonResponseAsync(stream, 400, new { success = false, error = ex.Message }, cancellationToken);
        }
        catch (JsonException ex)
        {
            await WriteJsonResponseAsync(stream, 400, new { success = false, error = $"Invalid JSON: {ex.Message}" }, cancellationToken);
        }
        catch (Exception ex)
        {
            await _error.WriteLineAsync($"[CentralServer] Editor attach request failed: {ex.Message}");
            try
            {
                await WriteJsonResponseAsync(stream, 500, new { success = false, error = ex.Message }, cancellationToken);
            }
            catch
            {
            }
        }
    }

    private async Task HandleAttachAsync(NetworkStream stream, byte[] body, CancellationToken cancellationToken)
    {
        var request = DeserializeBody<EditorSessionService.EditorSessionAttachRequest>(body);
        var result = _sessions.Attach(request);
        await WriteJsonResponseAsync(stream, 200, result, cancellationToken);
    }

    private async Task HandleHeartbeatAsync(NetworkStream stream, byte[] body, CancellationToken cancellationToken)
    {
        var request = DeserializeBody<EditorSessionService.EditorSessionHeartbeatRequest>(body);
        var result = _sessions.Heartbeat(request);
        await WriteJsonResponseAsync(stream, 200, result, cancellationToken);
    }

    private async Task HandleDetachAsync(NetworkStream stream, byte[] body, CancellationToken cancellationToken)
    {
        var request = DeserializeBody<EditorSessionService.EditorSessionDetachRequest>(body);
        var result = _sessions.Detach(request);
        await WriteJsonResponseAsync(stream, 200, result, cancellationToken);
    }

    private async Task HandleShutdownAsync(NetworkStream stream, CancellationToken cancellationToken)
    {
        await WriteJsonResponseAsync(stream, 200, new { success = true, shuttingDown = true }, cancellationToken);
        if (_shutdownRequested is not null)
        {
            _ = Task.Run(_shutdownRequested, CancellationToken.None);
        }
    }

    private static async Task<ParsedRequest> ReadRequestAsync(NetworkStream stream, CancellationToken cancellationToken)
    {
        var headerBytes = await ReadHeadersAsync(stream, cancellationToken);
        var headerText = Encoding.ASCII.GetString(headerBytes);
        var lines = headerText.Split("\r\n", StringSplitOptions.None);
        if (lines.Length == 0 || string.IsNullOrWhiteSpace(lines[0]))
        {
            throw new CentralToolException("Request line is missing.");
        }

        var requestLine = lines[0].Split(' ', StringSplitOptions.RemoveEmptyEntries);
        if (requestLine.Length < 2)
        {
            throw new CentralToolException("Malformed request line.");
        }

        var contentLength = 0;
        foreach (var line in lines.Skip(1))
        {
            if (string.IsNullOrWhiteSpace(line))
            {
                continue;
            }

            var separatorIndex = line.IndexOf(':');
            if (separatorIndex <= 0)
            {
                continue;
            }

            var headerName = line[..separatorIndex].Trim();
            var headerValue = line[(separatorIndex + 1)..].Trim();
            if (string.Equals(headerName, "Content-Length", StringComparison.OrdinalIgnoreCase))
            {
                int.TryParse(headerValue, out contentLength);
            }
        }

        var body = contentLength > 0
            ? await ReadExactAsync(stream, contentLength, cancellationToken)
            : [];

        return new ParsedRequest
        {
            Method = requestLine[0],
            Path = requestLine[1],
            Body = body,
        };
    }

    private static async Task<byte[]> ReadHeadersAsync(NetworkStream stream, CancellationToken cancellationToken)
    {
        var buffer = new List<byte>(256);
        var recent = new Queue<byte>(4);
        var singleByte = new byte[1];

        while (true)
        {
            var read = await stream.ReadAsync(singleByte, cancellationToken);
            if (read == 0)
            {
                throw new CentralToolException("Unexpected end of stream while reading headers.");
            }

            var current = singleByte[0];
            buffer.Add(current);
            recent.Enqueue(current);
            if (recent.Count > 4)
            {
                recent.Dequeue();
            }

            if (recent.Count == 4 && recent.ElementAt(0) == '\r' && recent.ElementAt(1) == '\n'
                && recent.ElementAt(2) == '\r' && recent.ElementAt(3) == '\n')
            {
                return buffer.ToArray();
            }
        }
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
                throw new CentralToolException("Unexpected end of stream while reading request body.");
            }

            offset += read;
        }

        return buffer;
    }

    private static T DeserializeBody<T>(byte[] body)
    {
        if (body.Length == 0)
        {
            throw new CentralToolException("Request body is required.");
        }

        var payload = JsonSerializer.Deserialize<T>(body, CentralServerSerialization.JsonOptions);
        if (payload is null)
        {
            throw new CentralToolException("Request body is required.");
        }

        return payload;
    }

    private static async Task WriteJsonResponseAsync(NetworkStream stream, int statusCode, object payload, CancellationToken cancellationToken)
    {
        var json = JsonSerializer.Serialize(payload, CentralServerSerialization.JsonOptions);
        var body = Encoding.UTF8.GetBytes(json);
        var header = Encoding.ASCII.GetBytes(
            $"HTTP/1.1 {statusCode} {GetReasonPhrase(statusCode)}\r\n" +
            "Content-Type: application/json; charset=utf-8\r\n" +
            $"Content-Length: {body.Length}\r\n" +
            "Connection: close\r\n\r\n");

        await stream.WriteAsync(header, cancellationToken);
        await stream.WriteAsync(body, cancellationToken);
        await stream.FlushAsync(cancellationToken);
    }

    private static string GetReasonPhrase(int statusCode)
    {
        return statusCode switch
        {
            200 => "OK",
            400 => "Bad Request",
            404 => "Not Found",
            405 => "Method Not Allowed",
            _ => "Internal Server Error",
        };
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

    private sealed class ParsedRequest
    {
        public string Method { get; set; } = string.Empty;

        public string Path { get; set; } = string.Empty;

        public byte[] Body { get; set; } = [];
    }
}
