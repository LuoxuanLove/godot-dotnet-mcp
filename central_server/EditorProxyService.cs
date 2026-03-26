using System.Net.Http.Json;
using System.Text.Json;

namespace GodotDotnetMcp.CentralServer;

internal sealed class EditorProxyService : IDisposable
{
    private const int DefaultForwardTimeoutMs = 60_000;
    private const int MinimumForwardTimeoutMs = 10_000;
    private const int MaximumForwardTimeoutMs = 300_000;
    private const int TimeoutSafetyMarginMs = 5_000;
    private const int DefaultInternalRequestTimeoutMs = 3_000;

    private readonly HttpClient _httpClient;

    public EditorProxyService()
    {
        _httpClient = new HttpClient
        {
            Timeout = Timeout.InfiniteTimeSpan,
        };
    }

    public async Task<ForwardedToolCallResult> ForwardToolCallAsync(
        EditorSessionService.EditorSessionStatus session,
        string toolName,
        JsonElement toolArguments,
        CancellationToken cancellationToken)
    {
        ValidateSession(session);

        var endpoint = BuildEndpoint(session);
        return await ForwardToolCallToEndpointAsync(endpoint, toolName, toolArguments, cancellationToken);
    }

    public Task<ForwardedToolCallResult> ForwardToolCallToEndpointAsync(
        string serverHost,
        int serverPort,
        string toolName,
        JsonElement toolArguments,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(serverHost) || serverPort <= 0)
        {
            throw new CentralToolException("A valid proxy endpoint is required.");
        }

        return ForwardToolCallToEndpointAsync(BuildEndpoint(serverHost, serverPort), toolName, toolArguments, cancellationToken);
    }

    public Task<InternalEndpointResult> GetEditorLifecycleStatusAsync(
        EditorSessionService.EditorSessionStatus session,
        CancellationToken cancellationToken)
    {
        ValidateSession(session);
        return SendInternalEndpointRequestAsync(
            BuildInternalEndpoint(session, "/api/editor/lifecycle"),
            HttpMethod.Get,
            body: null,
            TimeSpan.FromMilliseconds(DefaultInternalRequestTimeoutMs),
            cancellationToken);
    }

    public Task<InternalEndpointResult> ExecuteEditorLifecycleActionAsync(
        EditorSessionService.EditorSessionStatus session,
        string action,
        Dictionary<string, object?> arguments,
        CancellationToken cancellationToken)
    {
        ValidateSession(session);
        var body = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase)
        {
            ["action"] = action,
        };
        foreach (var pair in arguments)
        {
            body[pair.Key] = pair.Value;
        }

        return SendInternalEndpointRequestAsync(
            BuildInternalEndpoint(session, "/api/editor/lifecycle"),
            HttpMethod.Post,
            body,
            TimeSpan.FromMilliseconds(DefaultInternalRequestTimeoutMs),
            cancellationToken);
    }

    private async Task<ForwardedToolCallResult> ForwardToolCallToEndpointAsync(
        string endpoint,
        string toolName,
        JsonElement toolArguments,
        CancellationToken cancellationToken)
    {
        var requestTimeout = ResolveRequestTimeout(toolArguments);
        var rpcRequest = new
        {
            jsonrpc = "2.0",
            id = $"central-proxy-{Guid.NewGuid():N}",
            method = "tools/call",
            @params = new
            {
                name = toolName,
                arguments = toolArguments,
            },
        };

        using var timeoutCts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        timeoutCts.CancelAfter(requestTimeout);

        HttpResponseMessage response;
        string responseText;
        try
        {
            response = await _httpClient.PostAsJsonAsync(endpoint, rpcRequest, CentralServerSerialization.JsonOptions, timeoutCts.Token);
            responseText = await response.Content.ReadAsStringAsync(timeoutCts.Token);
        }
        catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested && timeoutCts.IsCancellationRequested)
        {
            throw new CentralToolException($"Editor proxy request timed out after {(int)requestTimeout.TotalMilliseconds} ms.");
        }

        using (response)
        {
        if (!response.IsSuccessStatusCode)
        {
            throw new CentralToolException($"Editor proxy HTTP request failed with status {(int)response.StatusCode}.");
        }

        try
        {
            using var document = JsonDocument.Parse(responseText);
            var root = document.RootElement;

            if (root.TryGetProperty("error", out var errorElement))
            {
                var message = errorElement.TryGetProperty("message", out var messageElement) && messageElement.ValueKind == JsonValueKind.String
                    ? messageElement.GetString() ?? "Editor proxy JSON-RPC error."
                    : "Editor proxy JSON-RPC error.";
                return new ForwardedToolCallResult(false, message, endpoint, new Dictionary<string, object?>
                {
                    ["jsonRpcError"] = JsonSerializer.Deserialize<object>(errorElement.GetRawText(), CentralServerSerialization.JsonOptions),
                });
            }

            if (!root.TryGetProperty("result", out var resultElement) || resultElement.ValueKind != JsonValueKind.Object)
            {
                throw new CentralToolException("Editor proxy response did not contain a JSON-RPC result object.");
            }

            var isError = resultElement.TryGetProperty("isError", out var isErrorElement)
                          && isErrorElement.ValueKind is JsonValueKind.True or JsonValueKind.False
                          && isErrorElement.GetBoolean();

            var contentText = ExtractPrimaryContentText(resultElement);
            object? parsedToolResult = null;
            if (!string.IsNullOrWhiteSpace(contentText))
            {
                parsedToolResult = JsonSerializer.Deserialize<object>(contentText, CentralServerSerialization.JsonOptions);
            }

            return new ForwardedToolCallResult(!isError, string.Empty, endpoint, parsedToolResult);
        }
        catch (JsonException ex)
        {
            throw new CentralToolException($"Editor proxy response parsing failed: {ex.Message}");
        }
        }
    }

    private async Task<InternalEndpointResult> SendInternalEndpointRequestAsync(
        string endpoint,
        HttpMethod method,
        object? body,
        TimeSpan timeout,
        CancellationToken cancellationToken)
    {
        using var request = new HttpRequestMessage(method, endpoint);
        if (body is not null)
        {
            request.Content = JsonContent.Create(body, options: CentralServerSerialization.JsonOptions);
        }

        using var timeoutCts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        timeoutCts.CancelAfter(timeout);

        HttpResponseMessage response;
        string responseText;
        try
        {
            response = await _httpClient.SendAsync(request, timeoutCts.Token);
            responseText = await response.Content.ReadAsStringAsync(timeoutCts.Token);
        }
        catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested && timeoutCts.IsCancellationRequested)
        {
            return new InternalEndpointResult(false, "editor_internal_timeout", $"Editor internal request timed out after {(int)timeout.TotalMilliseconds} ms.", endpoint, default);
        }

        using (response)
        {
            JsonElement payload = default;
            if (!string.IsNullOrWhiteSpace(responseText))
            {
                try
                {
                    using var document = JsonDocument.Parse(responseText);
                    payload = document.RootElement.Clone();
                }
                catch (JsonException ex)
                {
                    return new InternalEndpointResult(false, "editor_internal_parse_failed", $"Editor internal response parsing failed: {ex.Message}", endpoint, default);
                }
            }

            if (!response.IsSuccessStatusCode)
            {
                var errorType = ExtractString(payload, "error");
                var message = ExtractString(payload, "message");
                return new InternalEndpointResult(
                    false,
                    string.IsNullOrWhiteSpace(errorType) ? "editor_internal_http_error" : errorType,
                    string.IsNullOrWhiteSpace(message)
                        ? $"Editor internal request failed with status {(int)response.StatusCode}."
                        : message,
                    endpoint,
                    payload);
            }

            if (payload.ValueKind == JsonValueKind.Object
                && payload.TryGetProperty("success", out var successElement)
                && successElement.ValueKind is JsonValueKind.True or JsonValueKind.False
                && !successElement.GetBoolean())
            {
                return new InternalEndpointResult(
                    false,
                    ExtractString(payload, "error") ?? "editor_internal_failed",
                    ExtractString(payload, "message") ?? "Editor internal request failed.",
                    endpoint,
                    payload);
            }

            return new InternalEndpointResult(true, string.Empty, string.Empty, endpoint, payload);
        }
    }

    private static TimeSpan ResolveRequestTimeout(JsonElement toolArguments)
    {
        var toolTimeoutMs = CentralArgumentReader.GetOptionalPositiveInt(toolArguments, "timeout_ms");
        var attachTimeoutMs = CentralArgumentReader.GetOptionalPositiveInt(toolArguments, "editorAttachTimeoutMs");

        var candidateMs = DefaultForwardTimeoutMs;
        if (attachTimeoutMs is > 0)
        {
            candidateMs = Math.Max(candidateMs, attachTimeoutMs.Value);
        }

        if (toolTimeoutMs is > 0)
        {
            var withMargin = toolTimeoutMs.Value + TimeoutSafetyMarginMs;
            candidateMs = Math.Max(candidateMs, withMargin);
        }

        candidateMs = Math.Clamp(candidateMs, MinimumForwardTimeoutMs, MaximumForwardTimeoutMs);
        return TimeSpan.FromMilliseconds(candidateMs);
    }

    private static void ValidateSession(EditorSessionService.EditorSessionStatus session)
    {
        if (!session.Attached)
        {
            throw new CentralToolException("Editor proxy requires an attached editor session.");
        }

        var transportMode = session.TransportMode.Trim();
        if (!string.Equals(transportMode, "http", StringComparison.OrdinalIgnoreCase)
            && !string.Equals(transportMode, "both", StringComparison.OrdinalIgnoreCase))
        {
            throw new CentralToolException("Attached editor session does not expose an HTTP MCP endpoint.");
        }

        if (!session.ServerRunning)
        {
            throw new CentralToolException("Attached editor session is not currently serving MCP over HTTP.");
        }

        if (string.IsNullOrWhiteSpace(session.ServerHost) || session.ServerPort is null || session.ServerPort <= 0)
        {
            throw new CentralToolException("Attached editor session did not report a valid HTTP endpoint.");
        }
    }

    private static string BuildEndpoint(EditorSessionService.EditorSessionStatus session)
    {
        return BuildEndpoint(session.ServerHost, session.ServerPort ?? 0);
    }

    private static string BuildEndpoint(string serverHost, int serverPort)
    {
        return $"http://{serverHost}:{serverPort}/mcp";
    }

    private static string BuildInternalEndpoint(EditorSessionService.EditorSessionStatus session, string path)
    {
        return $"http://{session.ServerHost}:{session.ServerPort ?? 0}{path}";
    }

    private static string ExtractPrimaryContentText(JsonElement resultElement)
    {
        if (!resultElement.TryGetProperty("content", out var contentElement) || contentElement.ValueKind != JsonValueKind.Array)
        {
            return string.Empty;
        }

        foreach (var item in contentElement.EnumerateArray())
        {
            if (item.ValueKind != JsonValueKind.Object)
            {
                continue;
            }

            if (item.TryGetProperty("text", out var textElement) && textElement.ValueKind == JsonValueKind.String)
            {
                return textElement.GetString() ?? string.Empty;
            }
        }

        return string.Empty;
    }

    public void Dispose()
    {
        _httpClient.Dispose();
    }

    internal sealed record ForwardedToolCallResult(bool Success, string Message, string Endpoint, object? ToolResult);

    internal sealed record InternalEndpointResult(bool Success, string ErrorType, string Message, string Endpoint, JsonElement Payload);

    private static string? ExtractString(JsonElement payload, string propertyName)
    {
        return payload.ValueKind == JsonValueKind.Object
               && payload.TryGetProperty(propertyName, out var property)
               && property.ValueKind == JsonValueKind.String
            ? property.GetString()
            : null;
    }
}
