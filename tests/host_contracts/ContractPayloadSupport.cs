using System.Net;
using System.Net.Sockets;
using System.Text.Json;
using GodotDotnetMcp.CentralServer;

internal static class ContractPayloadSupport
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
            PluginVersion = "contract",
            GodotVersion = "contract",
            Capabilities = capabilities,
            TransportMode = "http",
            ServerHost = "127.0.0.1",
            ServerPort = mockPort,
            ServerRunning = true,
        };
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
}
