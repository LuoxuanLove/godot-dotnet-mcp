using Microsoft.Extensions.DependencyInjection;

namespace GodotDotnetMcp.CentralServer;

internal static class CentralServerServiceCollectionExtensions
{
    public static IServiceCollection AddCentralServerServices(this IServiceCollection services)
    {
        ArgumentNullException.ThrowIfNull(services);

        services.AddSingleton<CentralConfigurationService>();
        services.AddSingleton<EditorProcessService>();
        services.AddSingleton<GodotInstallationService>();
        services.AddSingleton<GodotProjectManagerProvider>();
        services.AddSingleton<ProjectRegistryService>();
        services.AddSingleton<EditorSessionService>();
        services.AddSingleton<EditorProxyService>();
        services.AddSingleton<CentralWorkspaceState>();
        services.AddSingleton<EditorSessionCoordinator>();
        services.AddSingleton<EditorLifecycleCoordinator>();
        services.AddSingleton<CentralToolDispatcher>();

        return services;
    }
}
