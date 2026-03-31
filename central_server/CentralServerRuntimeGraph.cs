using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

namespace GodotDotnetMcp.CentralServer;

internal sealed record CentralServerRuntimeGraph(
    ServiceProvider ServiceProvider,
    ILoggerFactory LoggerFactory,
    CentralConfigurationService Configuration,
    ProjectRegistryService Registry,
    EditorSessionService EditorSessions,
    EditorAttachEndpoint AttachEndpoint,
    EditorAttachHttpServer AttachServer,
    EditorProcessService? EditorProcesses,
    GodotInstallationService? GodotInstallations,
    GodotProjectManagerProvider? GodotProjectManager,
    CentralWorkspaceState? WorkspaceState,
    EditorSessionCoordinator? EditorSessionCoordinator,
    EditorLifecycleCoordinator? EditorLifecycleCoordinator,
    CentralToolDispatcher? Dispatcher,
    EditorProxyService? EditorProxy)
    : IDisposable
{
    public void Dispose()
    {
        ServiceProvider.Dispose();
    }
}
