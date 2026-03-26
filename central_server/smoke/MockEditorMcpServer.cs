using System.Net.Sockets;
using System.Text;
using System.Text.Json;
using static GodotDotnetMcp.CentralServer.SmokeHttpSupport;
using static GodotDotnetMcp.CentralServer.SmokePayloadSupport;

namespace GodotDotnetMcp.CentralServer;

internal sealed class MockEditorMcpServer : IAsyncDisposable
{
    private readonly TcpListener _listener;
    private readonly string _attachHost;
    private readonly int _attachPort;
    private readonly int _port;
    private readonly string _projectRoot;
    private readonly object _gate = new();
    private readonly List<string> _lifecycleActions = [];
    private Task? _serverTask;
    private string _projectId = string.Empty;
    private string _currentSessionId = string.Empty;
    private string[] _currentCapabilities = [];
    private bool _restartReattaches = true;
    private bool _closeDetaches = true;
    private int _restartCounter;

    public MockEditorMcpServer(string host, int port, string attachHost, int attachPort, string projectRoot)
    {
        _port = port;
        _attachHost = attachHost;
        _attachPort = attachPort;
        _projectRoot = projectRoot;
        _listener = new TcpListener(ParseAddress(host), port);
    }

    public string? LastRequestPayload { get; private set; }

    public IReadOnlyList<string> LifecycleActions
    {
        get
        {
            lock (_gate)
            {
                return _lifecycleActions.ToArray();
            }
        }
    }

    public void SetSession(string projectId, string sessionId, string[] capabilities)
    {
        lock (_gate)
        {
            _projectId = projectId;
            _currentSessionId = sessionId;
            _currentCapabilities = capabilities.ToArray();
        }
    }

    public void ConfigureLifecycleBehavior(bool restartReattaches = true, bool closeDetaches = true)
    {
        lock (_gate)
        {
            _restartReattaches = restartReattaches;
            _closeDetaches = closeDetaches;
        }
    }

    public void Start(CancellationToken cancellationToken)
    {
        _listener.Start();
        _serverTask = Task.Run(() => ServeAsync(cancellationToken), cancellationToken);
    }

    private async Task ServeAsync(CancellationToken cancellationToken)
    {
        try
        {
            while (!cancellationToken.IsCancellationRequested)
            {
                TcpClient client;
                try
                {
                    client = await _listener.AcceptTcpClientAsync(cancellationToken);
                }
                catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
                {
                    break;
                }

                _ = Task.Run(() => HandleClientAsync(client, cancellationToken), cancellationToken);
            }
        }
        catch when (cancellationToken.IsCancellationRequested)
        {
        }
        catch (ObjectDisposedException)
        {
        }
        catch (SocketException)
        {
        }
    }

    private async Task HandleClientAsync(TcpClient client, CancellationToken cancellationToken)
    {
        using (client)
        {
            await using var stream = client.GetStream();
            var request = await ReadIncomingRequestAsync(stream, cancellationToken);
            var response = await BuildResponseAsync(request, cancellationToken);
            await stream.WriteAsync(response.Header, cancellationToken);
            await stream.WriteAsync(response.Body, cancellationToken);
            await stream.FlushAsync(cancellationToken);
        }
    }

    private async Task<MockHttpResponse> BuildResponseAsync(IncomingHttpRequest request, CancellationToken cancellationToken)
    {
        if (string.Equals(request.Method, "POST", StringComparison.OrdinalIgnoreCase)
            && string.Equals(request.Path, "/mcp", StringComparison.OrdinalIgnoreCase))
        {
            return BuildJsonResponse(200, BuildMcpResponse(request));
        }

        if (string.Equals(request.Path, "/api/editor/lifecycle", StringComparison.OrdinalIgnoreCase))
        {
            if (!SupportsLifecycle())
            {
                return BuildJsonResponse(404, new
                {
                    success = false,
                    error = "mock_editor_lifecycle_unavailable",
                    message = "Mock editor lifecycle endpoint is unavailable for the current session.",
                });
            }

            if (string.Equals(request.Method, "GET", StringComparison.OrdinalIgnoreCase))
            {
                return BuildJsonResponse(200, BuildLifecycleStatusResponse());
            }

            if (string.Equals(request.Method, "POST", StringComparison.OrdinalIgnoreCase))
            {
                return await BuildLifecycleActionResponseAsync(request, cancellationToken);
            }
        }

        return BuildJsonResponse(404, new
        {
            success = false,
            error = "mock_not_found",
            message = $"Mock editor server does not handle {request.Method} {request.Path}.",
        });
    }

    private object BuildMcpResponse(IncomingHttpRequest request)
    {
        LastRequestPayload = request.Body.Length == 0
            ? string.Empty
            : Encoding.UTF8.GetString(request.Body);

        string toolName = "unknown";
        object? forwardedArguments = null;
        if (!string.IsNullOrWhiteSpace(LastRequestPayload))
        {
            using var document = JsonDocument.Parse(LastRequestPayload);
            if (document.RootElement.TryGetProperty("params", out var paramsElement))
            {
                if (paramsElement.TryGetProperty("name", out var nameElement) && nameElement.ValueKind == JsonValueKind.String)
                {
                    toolName = nameElement.GetString() ?? toolName;
                }

                if (paramsElement.TryGetProperty("arguments", out var argumentsElement))
                {
                    forwardedArguments = DeserializeToObject(argumentsElement.Clone());
                }
            }
        }

        var payloadText = JsonSerializer.Serialize(new
        {
            mockForwarded = true,
            toolName,
            echoArguments = forwardedArguments,
        }, CentralServerSerialization.JsonOptions);

        return new
        {
            jsonrpc = "2.0",
            id = "mock-response",
            result = new
            {
                content = new[]
                {
                    new
                    {
                        type = "text",
                        text = payloadText,
                    }
                },
                isError = false,
            },
        };
    }

    private object BuildLifecycleStatusResponse()
    {
        var sessionId = GetCurrentSessionId();
        return new
        {
            success = true,
            data = new
            {
                mockEditor = true,
                sessionId,
                currentScenePath = "res://Main.tscn",
                dirtySceneCount = 0,
                dirtyScenes = Array.Empty<string>(),
                openScenes = new[] { "res://Main.tscn" },
                isPlayingScene = false,
            },
            message = "Mock editor lifecycle status fetched.",
        };
    }

    private async Task<MockHttpResponse> BuildLifecycleActionResponseAsync(IncomingHttpRequest request, CancellationToken cancellationToken)
    {
        if (request.Body.Length == 0)
        {
            return BuildJsonResponse(400, new
            {
                success = false,
                error = "invalid_argument",
                message = "Mock lifecycle request body is required.",
            });
        }

        using var document = JsonDocument.Parse(request.Body);
        var root = document.RootElement;
        if (root.ValueKind != JsonValueKind.Object)
        {
            return BuildJsonResponse(400, new
            {
                success = false,
                error = "invalid_argument",
                message = "Mock lifecycle request body must be an object.",
            });
        }

        var action = root.TryGetProperty("action", out var actionElement) && actionElement.ValueKind == JsonValueKind.String
            ? actionElement.GetString() ?? string.Empty
            : string.Empty;
        if (string.IsNullOrWhiteSpace(action))
        {
            return BuildJsonResponse(400, new
            {
                success = false,
                error = "invalid_argument",
                message = "Mock lifecycle action is required.",
            });
        }

        if (!string.Equals(action, "close", StringComparison.OrdinalIgnoreCase)
            && !string.Equals(action, "restart", StringComparison.OrdinalIgnoreCase))
        {
            return BuildJsonResponse(400, new
            {
                success = false,
                error = "invalid_argument",
                message = $"Unsupported mock lifecycle action: {action}.",
            });
        }

        RecordLifecycleAction(action);
        var response = BuildJsonResponse(200, new
        {
            success = true,
            data = new
            {
                accepted = true,
                action,
                editor_state = BuildLifecycleStatusResponse(),
            },
            message = $"Mock editor lifecycle {action} accepted.",
        });

        _ = string.Equals(action, "close", StringComparison.OrdinalIgnoreCase)
            ? Task.Run(() => TriggerCloseAsync(cancellationToken), cancellationToken)
            : Task.Run(() => TriggerRestartAsync(cancellationToken), cancellationToken);

        return await Task.FromResult(response);
    }

    private async Task TriggerCloseAsync(CancellationToken cancellationToken)
    {
        try
        {
            if (!ShouldCloseDetach())
            {
                return;
            }

            var snapshot = GetSessionSnapshot();
            if (string.IsNullOrWhiteSpace(snapshot.ProjectId) || string.IsNullOrWhiteSpace(snapshot.SessionId))
            {
                return;
            }

            await Task.Delay(100, cancellationToken);
            await SendJsonRequestAsync(
                _attachHost,
                _attachPort,
                "POST",
                "/api/editor/detach",
                new EditorSessionService.EditorSessionDetachRequest
                {
                    ProjectId = snapshot.ProjectId,
                    ProjectRoot = _projectRoot,
                    SessionId = snapshot.SessionId,
                },
                cancellationToken);

            lock (_gate)
            {
                if (string.Equals(_currentSessionId, snapshot.SessionId, StringComparison.OrdinalIgnoreCase))
                {
                    _currentSessionId = string.Empty;
                    _currentCapabilities = [];
                }
            }
        }
        catch
        {
        }
    }

    private async Task TriggerRestartAsync(CancellationToken cancellationToken)
    {
        try
        {
            var snapshot = GetSessionSnapshot();
            if (string.IsNullOrWhiteSpace(snapshot.ProjectId) || string.IsNullOrWhiteSpace(snapshot.SessionId))
            {
                return;
            }

            var nextSessionId = $"smoke-lifecycle-r{Interlocked.Increment(ref _restartCounter)}";
            await Task.Delay(100, cancellationToken);
            await SendJsonRequestAsync(
                _attachHost,
                _attachPort,
                "POST",
                "/api/editor/detach",
                new EditorSessionService.EditorSessionDetachRequest
                {
                    ProjectId = snapshot.ProjectId,
                    ProjectRoot = _projectRoot,
                    SessionId = snapshot.SessionId,
                },
                cancellationToken);

            if (!ShouldRestartReattach())
            {
                lock (_gate)
                {
                    if (string.Equals(_currentSessionId, snapshot.SessionId, StringComparison.OrdinalIgnoreCase))
                    {
                        _currentSessionId = string.Empty;
                        _currentCapabilities = [];
                    }
                }

                return;
            }

            lock (_gate)
            {
                if (string.Equals(_currentSessionId, snapshot.SessionId, StringComparison.OrdinalIgnoreCase))
                {
                    _currentSessionId = nextSessionId;
                }
            }

            await Task.Delay(100, cancellationToken);
            await SendJsonRequestAsync(
                _attachHost,
                _attachPort,
                "POST",
                "/api/editor/attach",
                BuildMockAttachRequest(snapshot.ProjectId, _projectRoot, nextSessionId, snapshot.Capabilities, _port),
                cancellationToken);
        }
        catch
        {
        }
    }

    private bool SupportsLifecycle()
    {
        lock (_gate)
        {
            return _currentCapabilities.Any(capability =>
                string.Equals(capability, EditorSessionService.EditorLifecycleCapability, StringComparison.OrdinalIgnoreCase));
        }
    }

    private string GetCurrentSessionId()
    {
        lock (_gate)
        {
            return _currentSessionId;
        }
    }

    private bool ShouldRestartReattach()
    {
        lock (_gate)
        {
            return _restartReattaches;
        }
    }

    private bool ShouldCloseDetach()
    {
        lock (_gate)
        {
            return _closeDetaches;
        }
    }

    private (string ProjectId, string SessionId, string[] Capabilities) GetSessionSnapshot()
    {
        lock (_gate)
        {
            return (_projectId, _currentSessionId, _currentCapabilities.ToArray());
        }
    }

    private void RecordLifecycleAction(string action)
    {
        lock (_gate)
        {
            _lifecycleActions.Add(action);
        }
    }

    private static MockHttpResponse BuildJsonResponse(int statusCode, object payload)
    {
        var responseText = JsonSerializer.Serialize(payload, CentralServerSerialization.JsonOptions);
        var body = Encoding.UTF8.GetBytes(responseText);
        var reasonPhrase = statusCode switch
        {
            200 => "OK",
            400 => "Bad Request",
            404 => "Not Found",
            _ => "OK",
        };
        var header = Encoding.ASCII.GetBytes(
            $"HTTP/1.1 {statusCode} {reasonPhrase}\r\n" +
            "Content-Type: application/json; charset=utf-8\r\n" +
            $"Content-Length: {body.Length}\r\n" +
            "Connection: close\r\n\r\n");
        return new MockHttpResponse(header, body);
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

        if (_serverTask is not null)
        {
            try
            {
                await _serverTask;
            }
            catch
            {
            }
        }
    }

    private sealed record MockHttpResponse(byte[] Header, byte[] Body);
}
