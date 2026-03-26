using System.Text.Json;

namespace GodotDotnetMcp.CentralServer;

internal sealed class EditorLifecycleRemoteStateService
{
    private readonly EditorProxyService _editorProxy;

    public EditorLifecycleRemoteStateService(EditorProxyService editorProxy)
    {
        _editorProxy = editorProxy;
    }

    public async Task<Dictionary<string, object?>?> TryGetRemoteStatusAsync(
        EditorSessionService.EditorSessionStatus? session,
        CancellationToken cancellationToken)
    {
        if (session is null || !EditorSessionService.IsHttpReady(session))
        {
            return null;
        }

        if (!EditorSessionService.SupportsEditorLifecycle(session))
        {
            return BuildUnsupportedEditorLifecycleState(session);
        }

        try
        {
            var response = await _editorProxy.GetEditorLifecycleStatusAsync(session, cancellationToken);
            if (!response.Success)
            {
                return new Dictionary<string, object?>
                {
                    ["available"] = false,
                    ["error"] = response.ErrorType,
                    ["message"] = response.Message,
                    ["endpoint"] = response.Endpoint,
                };
            }

            return ExtractDataDictionary(response.Payload)
                ?? new Dictionary<string, object?>
                {
                    ["available"] = true,
                    ["endpoint"] = response.Endpoint,
                };
        }
        catch (Exception ex)
        {
            return new Dictionary<string, object?>
            {
                ["available"] = false,
                ["error"] = "editor_status_unavailable",
                ["message"] = ex.Message,
            };
        }
    }

    public static Dictionary<string, object?> BuildUnsupportedEditorLifecycleState(EditorSessionService.EditorSessionStatus session)
    {
        return new Dictionary<string, object?>
        {
            ["available"] = false,
            ["error"] = "editor_lifecycle_unsupported",
            ["message"] = "Attached editor session does not advertise internal editor lifecycle support.",
            ["endpoint"] = string.IsNullOrWhiteSpace(session.ServerHost) || session.ServerPort is null or <= 0
                ? string.Empty
                : $"http://{session.ServerHost}:{session.ServerPort}/api/editor/lifecycle",
            ["capabilities"] = session.Capabilities,
        };
    }

    private static Dictionary<string, object?>? ExtractDataDictionary(JsonElement payload)
    {
        if (payload.ValueKind != JsonValueKind.Object)
        {
            return null;
        }

        if (payload.TryGetProperty("data", out var dataElement) && dataElement.ValueKind == JsonValueKind.Object)
        {
            return JsonSerializer.Deserialize<Dictionary<string, object?>>(dataElement.GetRawText(), CentralServerSerialization.JsonOptions);
        }

        return JsonSerializer.Deserialize<Dictionary<string, object?>>(payload.GetRawText(), CentralServerSerialization.JsonOptions);
    }
}
