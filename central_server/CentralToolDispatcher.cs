using System.Diagnostics;
using System.Text.Json;
using GodotDotnetMcp.HostShared;
using Microsoft.Extensions.Logging;

namespace GodotDotnetMcp.CentralServer;

internal sealed class CentralToolDispatcher
{
    private readonly ILogger<CentralToolDispatcher> _logger;
    private readonly CentralToolHandlerRegistry _handlers;
    private readonly EditorAttachedToolForwardingService _editorToolForwarder;

    public CentralToolDispatcher(
        ILogger<CentralToolDispatcher> logger,
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
        _logger = logger;
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
        var sw = Stopwatch.StartNew();
        var isSystemTool = SystemToolCatalog.IsSystemTool(toolName);

        try
        {
            if (_handlers.TryGetHandler(toolName, out var handler))
            {
                var response = await handler(arguments, cancellationToken);
                sw.Stop();
                _logger.LogInformation("Tool dispatch: name={ToolName} category=workspace success=true duration={DurationMs}ms",
                    toolName, sw.ElapsedMilliseconds);
                return response;
            }

            var result = isSystemTool
                ? await _editorToolForwarder.ExecuteSystemToolAsync(toolName, arguments, cancellationToken)
                : await ExecuteDotnetToolAsync(toolName, arguments, cancellationToken);
            sw.Stop();
            _logger.LogInformation("Tool dispatch: name={ToolName} category=system success={Success} duration={DurationMs}ms",
                toolName, !result.IsError, sw.ElapsedMilliseconds);
            return result;
        }
        catch (CentralToolException ex)
        {
            sw.Stop();
            _logger.LogWarning("Tool dispatch: name={ToolName} category={Category} success=false error={Error} duration={DurationMs}ms",
                toolName, isSystemTool ? "system" : "workspace", ex.Message, sw.ElapsedMilliseconds);
            return CentralToolCallResponse.Error(ex.Message, new { error = ex.Message });
        }
        catch (BridgeToolException ex)
        {
            sw.Stop();
            _logger.LogWarning("Tool dispatch: name={ToolName} category=bridge success=false error={Error} duration={DurationMs}ms",
                toolName, ex.Message, sw.ElapsedMilliseconds);
            return CentralToolCallResponse.Error(ex.Message, new { error = ex.Message });
        }
        catch (Exception ex)
        {
            sw.Stop();
            _logger.LogError(ex, "Tool dispatch: name={ToolName} category={Category} success=false error=unhandled duration={DurationMs}ms",
                toolName, isSystemTool ? "system" : "workspace", sw.ElapsedMilliseconds);
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
