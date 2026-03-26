using System.Text.Json;
using GodotDotnetMcp.HostShared;

namespace GodotDotnetMcp.CentralServer;

internal sealed class CentralToolDispatcher
{
    private readonly CentralToolHandlerRegistry _handlers;
    private readonly EditorAttachedToolForwardingService _editorToolForwarder;

    public CentralToolDispatcher(
        CentralConfigurationService configuration,
        EditorProxyService editorProxy,
        EditorProcessService _,
        EditorLifecycleCoordinator editorLifecycleCoordinator,
        EditorSessionCoordinator editorSessionCoordinator,
        EditorSessionService editorSessions,
        GodotInstallationService godotInstallations,
        GodotProjectManagerProvider godotProjectManager,
        ProjectRegistryService registry,
        CentralWorkspaceState workspaceState)
    {
        var hostSessionPayloadFactory = new CentralHostSessionPayloadFactory(
            editorLifecycleCoordinator,
            editorSessionCoordinator,
            workspaceState);
        var workspaceTools = new WorkspaceToolHandlerService(
            configuration,
            editorSessions,
            godotInstallations,
            godotProjectManager,
            registry,
            workspaceState);
        var workspaceEditorSessionTools = new WorkspaceEditorSessionToolHandlerService(
            editorLifecycleCoordinator,
            editorSessionCoordinator,
            hostSessionPayloadFactory);
        var editorTools = new EditorToolHandlerService(
            editorLifecycleCoordinator,
            workspaceEditorSessionTools);
        _editorToolForwarder = new EditorAttachedToolForwardingService(
            editorProxy,
            editorSessionCoordinator,
            hostSessionPayloadFactory);
        _handlers = BuildHandlerRegistry(workspaceTools, editorTools);
    }

    public async Task<CentralToolCallResponse> ExecuteAsync(string toolName, JsonElement arguments, CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();

        try
        {
            if (_handlers.TryGetHandler(toolName, out var handler))
            {
                return await handler(arguments, cancellationToken);
            }

            return SystemToolCatalog.IsSystemTool(toolName)
                ? await _editorToolForwarder.ExecuteSystemToolAsync(toolName, arguments, cancellationToken)
                : await ExecuteDotnetToolAsync(toolName, arguments, cancellationToken);
        }
        catch (CentralToolException ex)
        {
            return CentralToolCallResponse.Error(ex.Message, new { error = ex.Message });
        }
        catch (BridgeToolException ex)
        {
            return CentralToolCallResponse.Error(ex.Message, new { error = ex.Message });
        }
        catch (Exception ex)
        {
            return CentralToolCallResponse.Error(
                $"Tool execution failed: {ex.Message}",
                new { error = ex.Message, exception = ex.GetType().Name });
        }
    }

    private static CentralToolHandlerRegistry BuildHandlerRegistry(
        WorkspaceToolHandlerService workspaceTools,
        EditorToolHandlerService editorTools)
    {
        var handlers = new CentralToolHandlerRegistry();
        workspaceTools.RegisterHandlers(handlers);
        editorTools.RegisterHandlers(handlers);
        return handlers;
    }

    private static async Task<CentralToolCallResponse> ExecuteDotnetToolAsync(
        string toolName,
        JsonElement arguments,
        CancellationToken cancellationToken)
    {
        var response = await BridgeToolDispatcher.ExecuteAsync(toolName, arguments, cancellationToken);
        return response.IsError
            ? CentralToolCallResponse.Error(response.TextContent, response.StructuredContent)
            : CentralToolCallResponse.Success(response.StructuredContent);
    }
}
