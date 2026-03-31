using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

namespace GodotDotnetMcp.CentralServer;

internal static class CentralServerComposition
{
    public static CentralServerRuntimeGraph BuildStdioGraph(
        EditorAttachEndpoint attachEndpoint,
        EditorAttachHttpServer attachServer,
        Action<ILoggingBuilder>? configureLogging = null)
    {
        ArgumentNullException.ThrowIfNull(attachEndpoint);
        ArgumentNullException.ThrowIfNull(attachServer);

        var serviceProvider = BuildServiceProvider(attachEndpoint, configureLogging);
        try
        {
            var runtimeGraph = new CentralServerRuntimeGraph(
                ServiceProvider: serviceProvider,
                Configuration: serviceProvider.GetRequiredService<CentralConfigurationService>(),
                Registry: serviceProvider.GetRequiredService<ProjectRegistryService>(),
                EditorSessions: serviceProvider.GetRequiredService<EditorSessionService>(),
                AttachEndpoint: attachEndpoint,
                AttachServer: attachServer,
                EditorProcesses: serviceProvider.GetRequiredService<EditorProcessService>(),
                GodotInstallations: serviceProvider.GetRequiredService<GodotInstallationService>(),
                GodotProjectManager: serviceProvider.GetRequiredService<GodotProjectManagerProvider>(),
                WorkspaceState: serviceProvider.GetRequiredService<CentralWorkspaceState>(),
                EditorSessionCoordinator: serviceProvider.GetRequiredService<EditorSessionCoordinator>(),
                EditorLifecycleCoordinator: serviceProvider.GetRequiredService<EditorLifecycleCoordinator>(),
                Dispatcher: serviceProvider.GetRequiredService<CentralToolDispatcher>(),
                EditorProxy: serviceProvider.GetRequiredService<EditorProxyService>());

            runtimeGraph.GodotProjectManager?.StartWatcher();
            return runtimeGraph;
        }
        catch
        {
            serviceProvider.Dispose();
            throw;
        }
    }

    public static CentralServerRuntimeGraph BuildAttachOnlyGraph(
        EditorAttachEndpoint attachEndpoint,
        EditorAttachHttpServer attachServer,
        Action<ILoggingBuilder>? configureLogging = null)
    {
        ArgumentNullException.ThrowIfNull(attachEndpoint);
        ArgumentNullException.ThrowIfNull(attachServer);

        var serviceProvider = BuildServiceProvider(attachEndpoint, configureLogging);
        try
        {
            return new CentralServerRuntimeGraph(
                ServiceProvider: serviceProvider,
                Configuration: serviceProvider.GetRequiredService<CentralConfigurationService>(),
                Registry: serviceProvider.GetRequiredService<ProjectRegistryService>(),
                EditorSessions: serviceProvider.GetRequiredService<EditorSessionService>(),
                AttachEndpoint: attachEndpoint,
                AttachServer: attachServer,
                EditorProcesses: null,
                GodotInstallations: null,
                GodotProjectManager: null,
                WorkspaceState: null,
                EditorSessionCoordinator: null,
                EditorLifecycleCoordinator: null,
                Dispatcher: null,
                EditorProxy: null);
        }
        catch
        {
            serviceProvider.Dispose();
            throw;
        }
    }

    private static ServiceProvider BuildServiceProvider(
        EditorAttachEndpoint attachEndpoint,
        Action<ILoggingBuilder>? configureLogging)
    {
        var services = new ServiceCollection();
        services.AddLogging(logging => configureLogging?.Invoke(logging));
        services.AddSingleton(attachEndpoint);
        services.AddCentralServerServices();
        return services.BuildServiceProvider();
    }

    /// <summary>
    /// Creates the full stdio runtime: resolves all services from DI, creates and starts the attach server.
    /// Use this from CentralServerApplication.RunStdioAsync.
    /// </summary>
    public static StdioRuntime CreateStdioRuntime(
        EditorAttachEndpoint attachEndpoint,
        TextWriter error,
        Func<Task>? shutdownRequested,
        Action<ILoggingBuilder>? configureLogging = null)
    {
        ArgumentNullException.ThrowIfNull(attachEndpoint);
        ArgumentNullException.ThrowIfNull(error);

        var serviceProvider = BuildServiceProvider(attachEndpoint, configureLogging);
        try
        {
            var editorSessions = serviceProvider.GetRequiredService<EditorSessionService>();
            var attachServer = new EditorAttachHttpServer(
                attachEndpoint.Host,
                attachEndpoint.Port,
                editorSessions,
                error,
                shutdownRequested);

            var runtimeGraph = new CentralServerRuntimeGraph(
                ServiceProvider: serviceProvider,
                Configuration: serviceProvider.GetRequiredService<CentralConfigurationService>(),
                Registry: serviceProvider.GetRequiredService<ProjectRegistryService>(),
                EditorSessions: editorSessions,
                AttachEndpoint: attachEndpoint,
                AttachServer: attachServer,
                EditorProcesses: serviceProvider.GetRequiredService<EditorProcessService>(),
                GodotInstallations: serviceProvider.GetRequiredService<GodotInstallationService>(),
                GodotProjectManager: serviceProvider.GetRequiredService<GodotProjectManagerProvider>(),
                WorkspaceState: serviceProvider.GetRequiredService<CentralWorkspaceState>(),
                EditorSessionCoordinator: serviceProvider.GetRequiredService<EditorSessionCoordinator>(),
                EditorLifecycleCoordinator: serviceProvider.GetRequiredService<EditorLifecycleCoordinator>(),
                Dispatcher: serviceProvider.GetRequiredService<CentralToolDispatcher>(),
                EditorProxy: serviceProvider.GetRequiredService<EditorProxyService>());

            runtimeGraph.GodotProjectManager?.StartWatcher();
            return new StdioRuntime(attachServer, runtimeGraph);
        }
        catch
        {
            serviceProvider.Dispose();
            throw;
        }
    }

    /// <summary>
    /// Creates the minimal attach-only runtime: resolves only the services needed for attach server.
    /// Use this from CentralServerApplication.RunAttachOnlyAsync.
    /// </summary>
    public static AttachOnlyRuntime CreateAttachOnlyRuntime(
        EditorAttachEndpoint attachEndpoint,
        TextWriter error,
        Func<Task>? shutdownRequested,
        Action<ILoggingBuilder>? configureLogging = null)
    {
        ArgumentNullException.ThrowIfNull(attachEndpoint);
        ArgumentNullException.ThrowIfNull(error);

        var serviceProvider = BuildServiceProvider(attachEndpoint, configureLogging);
        try
        {
            var editorSessions = serviceProvider.GetRequiredService<EditorSessionService>();
            var attachServer = new EditorAttachHttpServer(
                attachEndpoint.Host,
                attachEndpoint.Port,
                editorSessions,
                error,
                shutdownRequested);

            return new AttachOnlyRuntime(attachServer, serviceProvider);
        }
        catch
        {
            serviceProvider.Dispose();
            throw;
        }
    }

    public sealed class StdioRuntime : IAsyncDisposable, IDisposable
    {
        public EditorAttachHttpServer AttachServer { get; }
        public CentralServerRuntimeGraph Graph { get; }

        public StdioRuntime(EditorAttachHttpServer attachServer, CentralServerRuntimeGraph graph)
        {
            AttachServer = attachServer;
            Graph = graph;
        }

        public async ValueTask DisposeAsync()
        {
            await AttachServer.DisposeAsync();
            Graph.Dispose();
        }

        public void Dispose()
        {
            AttachServer.DisposeAsync().AsTask().GetAwaiter().GetResult();
            Graph.Dispose();
        }
    }

    public sealed class AttachOnlyRuntime : IAsyncDisposable, IDisposable
    {
        public EditorAttachHttpServer AttachServer { get; }
        private readonly ServiceProvider _serviceProvider;

        public AttachOnlyRuntime(EditorAttachHttpServer attachServer, ServiceProvider serviceProvider)
        {
            AttachServer = attachServer;
            _serviceProvider = serviceProvider;
        }

        public async ValueTask DisposeAsync()
        {
            await AttachServer.DisposeAsync();
            _serviceProvider.Dispose();
        }

        public void Dispose()
        {
            AttachServer.DisposeAsync().AsTask().GetAwaiter().GetResult();
            _serviceProvider.Dispose();
        }
    }
}
