using Microsoft.Extensions.DependencyInjection;

namespace GodotDotnetMcp.CentralServer;

internal sealed record CentralServerRuntimeGraph(
    ServiceProvider ServiceProvider,
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
