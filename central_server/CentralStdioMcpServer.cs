using System.Buffers;
using System.Text;
using System.Text.Json;

namespace GodotDotnetMcp.CentralServer;

internal sealed class CentralStdioMcpServer
{
    private const int MaxHeaderBytes = 16 * 1024;

    private readonly Stream _output;
    private readonly TextWriter _error;
    private readonly CentralToolDispatcher _dispatcher;

    public CentralStdioMcpServer(Stream output, TextWriter error, CentralToolDispatcher dispatcher)
    {
        _output = output;
        _error = error;
        _dispatcher = dispatcher;
    }

    public async Task RunAsync(Stream input, CancellationToken cancellationToken)
    {
        try
        {
            while (!cancellationToken.IsCancellationRequested)
            {
                InboundMessage? message;
                try
                {
                    message = await ReadMessageAsync(input, cancellationToken);
                }
                catch (EndOfStreamException)
                {
                    return;
                }

                if (message is null)
                {
                    return;
                }

                if (!TryParseRequest(message.Body, out var request, out var parseError))
                {
                    await _error.WriteLineAsync(parseError ?? "Invalid JSON-RPC request.");
                    await _error.FlushAsync();
                    continue;
                }

                if (request is null)
                {
                    continue;
                }

                if (request.Method == "exit")
                {
                    return;
                }

                if (request.Method == "initialized")
                {
                    continue;
                }

                if (request.IsNotification)
                {
                    continue;
                }

                try
                {
                    await HandleRequestAsync(request, cancellationToken);
                }
                catch (Exception ex)
                {
                    await WriteErrorAsync(request.Id, -32603, $"Internal error: {ex.Message}", cancellationToken);
                    await _error.WriteLineAsync(ex.ToString());
                    await _error.FlushAsync();
                }
            }
        }
        catch (EndOfStreamException)
        {
            return;
        }
    }

    private async Task HandleRequestAsync(JsonRpcRequest request, CancellationToken cancellationToken)
    {
        object? result = request.Method switch
        {
            "initialize" => CreateInitializeResult(),
            "ping" => new { },
            "tools/list" => new { tools = CentralToolCatalog.GetTools() },
            "tools/call" => await HandleToolCallAsync(request, cancellationToken),
            "shutdown" => null,
            _ => CreateMethodNotFound(request.Method),
        };

        if (result is MethodNotFoundResponse methodNotFound)
        {
            await WriteErrorAsync(request.Id!, -32601, methodNotFound.Message, cancellationToken);
            return;
        }

        if (result is JsonRpcErrorPayload errorPayload)
        {
            await WriteErrorAsync(request.Id!, errorPayload.Code, errorPayload.Message, cancellationToken);
            return;
        }

        await WriteResultAsync(request.Id!, result, cancellationToken);
    }

    private async Task<object> HandleToolCallAsync(JsonRpcRequest request, CancellationToken cancellationToken)
    {
        if (!TryGetToolCallArguments(request.Raw, out var toolName, out var toolArguments, out var errorMessage))
        {
            return new JsonRpcErrorPayload(-32602, errorMessage ?? "Invalid tools/call arguments.");
        }

        var toolResult = await _dispatcher.ExecuteAsync(toolName, toolArguments, cancellationToken);
        return new
        {
            content = new[]
            {
                new
                {
                    type = "text",
                    text = toolResult.TextContent,
                }
            },
            structuredContent = toolResult.StructuredContent,
            isError = toolResult.IsError,
        };
    }

    private object CreateInitializeResult()
    {
        return new
        {
            protocolVersion = "2024-11-05",
            serverInfo = new
            {
                name = CentralServerManifest.ProductName,
                version = CentralServerManifest.Version,
            },
            capabilities = new
            {
                tools = new
                {
                    listChanged = false,
                },
                logging = new { },
            },
        };
    }

    private static MethodNotFoundResponse CreateMethodNotFound(string method) => new($"Method not found: {method}");

    private async Task WriteResultAsync(string? id, object? result, CancellationToken cancellationToken)
    {
        var payload = new Dictionary<string, object?>
        {
            ["jsonrpc"] = "2.0",
            ["id"] = id,
            ["result"] = result,
        };

        await CentralServerApplication.WriteJsonAsync(_output, payload, cancellationToken);
    }

    private async Task WriteErrorAsync(string? id, int code, string message, CancellationToken cancellationToken)
    {
        var payload = new Dictionary<string, object?>
        {
            ["jsonrpc"] = "2.0",
            ["id"] = id,
            ["error"] = new
            {
                code,
                message,
            },
        };

        await CentralServerApplication.WriteJsonAsync(_output, payload, cancellationToken);
    }

    private static bool TryParseRequest(ReadOnlyMemory<byte> body, out JsonRpcRequest? request, out string? error)
    {
        request = null;
        error = null;

        try
        {
            using var document = JsonDocument.Parse(body);
            var root = document.RootElement;

            if (!root.TryGetProperty("method", out var methodProperty) || methodProperty.ValueKind != JsonValueKind.String)
            {
                error = "Missing JSON-RPC method.";
                return false;
            }

            string? id = null;
            var isNotification = !root.TryGetProperty("id", out var idProperty) || idProperty.ValueKind == JsonValueKind.Null;
            if (!isNotification)
            {
                id = idProperty.ValueKind switch
                {
                    JsonValueKind.String => idProperty.GetString(),
                    JsonValueKind.Number => idProperty.GetRawText(),
                    JsonValueKind.True => "true",
                    JsonValueKind.False => "false",
                    _ => idProperty.GetRawText(),
                };
            }

            request = new JsonRpcRequest(
                Method: methodProperty.GetString() ?? string.Empty,
                Id: id,
                IsNotification: isNotification,
                Raw: root.Clone());

            return true;
        }
        catch (JsonException ex)
        {
            error = ex.Message;
            return false;
        }
    }

    private static bool TryGetToolCallArguments(JsonElement requestRoot, out string toolName, out JsonElement toolArguments, out string? errorMessage)
    {
        toolName = string.Empty;
        toolArguments = default;
        errorMessage = null;

        if (!requestRoot.TryGetProperty("params", out var paramsElement) || paramsElement.ValueKind != JsonValueKind.Object)
        {
            errorMessage = "Missing tools/call params.";
            return false;
        }

        if (!paramsElement.TryGetProperty("name", out var nameElement) || nameElement.ValueKind != JsonValueKind.String)
        {
            errorMessage = "Missing tools/call params.name.";
            return false;
        }

        toolName = nameElement.GetString() ?? string.Empty;
        if (string.IsNullOrWhiteSpace(toolName))
        {
            errorMessage = "tools/call params.name cannot be empty.";
            return false;
        }

        if (paramsElement.TryGetProperty("arguments", out var argumentsElement) && argumentsElement.ValueKind == JsonValueKind.Object)
        {
            toolArguments = argumentsElement.Clone();
        }
        else
        {
            using var emptyDocument = JsonDocument.Parse("{}");
            toolArguments = emptyDocument.RootElement.Clone();
        }

        return true;
    }

    private static async Task<InboundMessage?> ReadMessageAsync(Stream input, CancellationToken cancellationToken)
    {
        var headerBuffer = new ArrayBufferWriter<byte>();
        var singleByte = new byte[1];

        while (true)
        {
            var read = await input.ReadAsync(singleByte.AsMemory(0, 1), cancellationToken);
            if (read == 0)
            {
                if (headerBuffer.WrittenCount == 0)
                {
                    return null;
                }

                throw new EndOfStreamException("Unexpected end of stream while reading headers.");
            }

            headerBuffer.Write(singleByte);
            if (headerBuffer.WrittenCount > MaxHeaderBytes)
            {
                throw new InvalidDataException("Header section exceeds the maximum supported size.");
            }

            if (EndsWithDoubleCrlf(headerBuffer.WrittenSpan))
            {
                break;
            }
        }

        var headerText = Encoding.ASCII.GetString(headerBuffer.WrittenSpan);
        var contentLength = ParseContentLength(headerText);
        if (contentLength < 0)
        {
            throw new InvalidDataException("Missing Content-Length header.");
        }

        var body = new byte[contentLength];
        var offset = 0;
        while (offset < contentLength)
        {
            var read = await input.ReadAsync(body.AsMemory(offset, contentLength - offset), cancellationToken);
            if (read == 0)
            {
                throw new EndOfStreamException("Unexpected end of stream while reading message body.");
            }

            offset += read;
        }

        return new InboundMessage(contentLength, body);
    }

    private static bool EndsWithDoubleCrlf(ReadOnlySpan<byte> buffer)
    {
        return buffer.Length >= 4 &&
               buffer[^4] == '\r' &&
               buffer[^3] == '\n' &&
               buffer[^2] == '\r' &&
               buffer[^1] == '\n';
    }

    private static int ParseContentLength(string headerText)
    {
        foreach (var line in headerText.Split("\r\n", StringSplitOptions.RemoveEmptyEntries))
        {
            if (!line.StartsWith("Content-Length:", StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }

            var value = line["Content-Length:".Length..].Trim();
            if (int.TryParse(value, out var contentLength) && contentLength >= 0)
            {
                return contentLength;
            }
        }

        return -1;
    }

    private sealed record InboundMessage(int ContentLength, byte[] Body);

    private sealed record JsonRpcRequest(string Method, string? Id, bool IsNotification, JsonElement Raw);

    private sealed record MethodNotFoundResponse(string Message);

    private sealed record JsonRpcErrorPayload(int Code, string Message);
}
