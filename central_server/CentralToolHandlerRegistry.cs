using System.Text.Json;

namespace GodotDotnetMcp.CentralServer;

internal delegate Task<CentralToolCallResponse> CentralToolHandler(JsonElement arguments, CancellationToken cancellationToken);

internal sealed class CentralToolHandlerRegistry
{
    private readonly Dictionary<string, CentralToolHandler> _handlers = new(StringComparer.Ordinal);

    public CentralToolHandlerRegistry Register(string toolName, CentralToolHandler handler)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(toolName);
        ArgumentNullException.ThrowIfNull(handler);

        _handlers[toolName] = handler;
        return this;
    }

    public bool TryGetHandler(string toolName, out CentralToolHandler handler)
    {
        return _handlers.TryGetValue(toolName, out handler!);
    }
}
