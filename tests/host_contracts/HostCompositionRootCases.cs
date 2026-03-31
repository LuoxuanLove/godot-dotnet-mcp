using System.Net;
using System.Net.Sockets;
using System.Reflection;
using System.Text;
using System.Text.Json;
using GodotDotnetMcp.CentralServer;
using static ContractAssertions;
using static ContractHttpSupport;
using static ContractPayloadSupport;

internal static class HostCompositionRootCases
{
    public static async Task VerifyStdioModeBuildsFullHostGraphAsync()
    {
        await using var host = HostGraphHarness.CreateStdio("stdio_mode_builds_full_host_graph");

        if (host.WorkspaceState is null
            || host.Registry is null
            || host.EditorSessions is null
            || host.EditorSessionCoordinator is null
            || host.EditorLifecycleCoordinator is null
            || host.Dispatcher is null
            || host.AttachServer is null)
        {
            throw new InvalidOperationException("Stdio mode should build the full host composition graph.");
        }

        if (host.AttachServer.Prefix.IndexOf($":{host.AttachPort}/", StringComparison.Ordinal) < 0)
        {
            throw new InvalidOperationException("Attach server prefix did not include the configured endpoint.");
        }
    }

    public static async Task VerifyStdioModePropagatesAttachEndpointConfigurationAsync()
    {
        const string customHost = "127.0.0.1";
        var customPort = GetFreeTcpPort();

        await using var host = HostGraphHarness.CreateStdio(
            "stdio_mode_propagates_attach_endpoint_configuration",
            ["--attach-host", customHost, "--attach-port", customPort.ToString()]);

        if (!string.Equals(host.AttachEndpoint.Host, customHost, StringComparison.Ordinal)
            || host.AttachEndpoint.Port != customPort)
        {
            throw new InvalidOperationException("Stdio mode did not propagate custom --attach-host/--attach-port into the composition root.");
        }

        var projectId = await host.RegisterProjectAsync();
        var response = await host.Dispatcher!.ExecuteAsync(
            "system_project_state",
            SerializeToElement(new
            {
                projectId,
                autoLaunchEditor = false,
            }),
            CancellationToken.None);

        var payload = EnsureExpectedError(response, "system_project_state", "editor_required");
        AssertNestedString(payload, customHost, "centralHostSession", "attachHost");

        var actualAttachPort = payload.GetProperty("centralHostSession").GetProperty("attachPort").GetInt32();
        if (actualAttachPort != customPort)
        {
            throw new InvalidOperationException($"Expected centralHostSession.attachPort={customPort}, got {actualAttachPort}.");
        }
    }

    public static async Task VerifyAttachOnlyModeBuildsMinimalHostGraphAsync()
    {
        await using var host = HostGraphHarness.CreateAttachOnly("attach_only_mode_builds_minimal_host_graph");

        if (host.Registry is null || host.EditorSessions is null || host.AttachServer is null)
        {
            throw new InvalidOperationException("Attach-only mode should build attach server + registry + editor session state.");
        }

        if (host.WorkspaceState is not null
            || host.EditorSessionCoordinator is not null
            || host.EditorLifecycleCoordinator is not null
            || host.Dispatcher is not null)
        {
            throw new InvalidOperationException("Attach-only mode should not wire stdio dispatcher/coordinator graph.");
        }

        var health = await SendJsonRequestAsync(
            host.AttachHost,
            host.AttachPort,
            "GET",
            "/api/server/health",
            body: null,
            CancellationToken.None);
        AssertNestedBoolean(health, true, "success");
    }

    public static async Task VerifyHostGraphSharesWorkspaceStateAcrossDispatcherAndCoordinatorsAsync()
    {
        await using var host = HostGraphHarness.CreateStdio("host_graph_shares_workspace_state_across_dispatcher_and_coordinators");

        var forwarder = GetRequiredFieldValue(host.Dispatcher!, "_editorToolForwarder");
        var payloadFactory = GetRequiredFieldValue(forwarder, "_hostSessionPayloadFactory");
        var sessionCoordinatorFromDispatcher = GetRequiredFieldValue(forwarder, "_editorSessionCoordinator");
        var workspaceFromPayloadFactory = GetRequiredFieldValue(payloadFactory, "_workspaceState");

        var acquisitionService = GetRequiredFieldValue(host.EditorSessionCoordinator!, "_acquisitionService");
        var workspaceFromAcquisition = GetRequiredFieldValue(acquisitionService, "_workspaceState");
        var sessionsFromAcquisition = GetRequiredFieldValue(acquisitionService, "_editorSessions");

        var lifecycleStatusService = GetRequiredFieldValue(host.EditorLifecycleCoordinator!, "_statusService");
        var lifecycleActionService = GetRequiredFieldValue(host.EditorLifecycleCoordinator!, "_actionService");
        var workspaceFromStatus = GetRequiredFieldValue(lifecycleStatusService, "_workspaceState");
        var workspaceFromAction = GetRequiredFieldValue(lifecycleActionService, "_workspaceState");
        var sessionsFromAction = GetRequiredFieldValue(lifecycleActionService, "_editorSessions");

        var sessionsFromAttachServer = GetRequiredFieldValue(host.AttachServer!, "_sessions");

        AssertReferenceEquals(host.EditorSessionCoordinator!, sessionCoordinatorFromDispatcher, "dispatcher -> session coordinator");
        AssertReferenceEquals(host.WorkspaceState!, workspaceFromPayloadFactory, "payload factory -> workspace state");
        AssertReferenceEquals(host.WorkspaceState!, workspaceFromAcquisition, "session acquisition -> workspace state");
        AssertReferenceEquals(host.WorkspaceState!, workspaceFromStatus, "lifecycle status -> workspace state");
        AssertReferenceEquals(host.WorkspaceState!, workspaceFromAction, "lifecycle action -> workspace state");
        AssertReferenceEquals(host.EditorSessions!, sessionsFromAcquisition, "session acquisition -> editor sessions");
        AssertReferenceEquals(host.EditorSessions!, sessionsFromAction, "lifecycle action -> editor sessions");
        AssertReferenceEquals(host.EditorSessions!, sessionsFromAttachServer, "attach server -> editor sessions");

        var projectId = await host.RegisterProjectAsync();
        var response = await host.Dispatcher!.ExecuteAsync(
            "system_project_state",
            SerializeToElement(new
            {
                projectId,
                autoLaunchEditor = false,
            }),
            CancellationToken.None);
        EnsureExpectedError(response, "system_project_state", "editor_required");

        if (!string.Equals(host.WorkspaceState!.ActiveProjectId, projectId, StringComparison.Ordinal))
        {
            throw new InvalidOperationException("Dispatcher and coordinators should operate over the same workspace state instance.");
        }
    }

    public static async Task VerifyDiStyleCompositionGraphMatchesManualAsync()
    {
        // Phase 2 DI regression: validates that a DI-style composition path produces
        // the same service graph shape as the existing manual composition.
        // This test acts as a baseline: it passes now with manual composition,
        // and must continue to pass after DI container is introduced.
        await using var host = HostGraphHarness.CreateStdio("di_style_graph_matches_manual");

        // Verify full graph services exist
        if (host.Configuration is null)
        {
            throw new InvalidOperationException("Configuration service should exist in stdio composition.");
        }

        if (host.Registry is null)
        {
            throw new InvalidOperationException("Registry service should exist in stdio composition.");
        }

        if (host.EditorSessions is null)
        {
            throw new InvalidOperationException("Editor sessions service should exist in stdio composition.");
        }

        if (host.EditorSessionCoordinator is null)
        {
            throw new InvalidOperationException("Editor session coordinator should exist in stdio composition.");
        }

        if (host.EditorLifecycleCoordinator is null)
        {
            throw new InvalidOperationException("Editor lifecycle coordinator should exist in stdio composition.");
        }

        if (host.Dispatcher is null)
        {
            throw new InvalidOperationException("Tool dispatcher should exist in stdio composition.");
        }

        if (host.AttachServer is null)
        {
            throw new InvalidOperationException("Attach server should exist in stdio composition.");
        }

        if (host.WorkspaceState is null)
        {
            throw new InvalidOperationException("Workspace state should exist in stdio composition.");
        }

        // Verify attach endpoint is configured
        if (host.AttachServer.Prefix.IndexOf($":{host.AttachPort}/", StringComparison.Ordinal) < 0)
        {
            throw new InvalidOperationException("Attach server prefix did not include the configured endpoint.");
        }
    }

    public static async Task VerifySingletonServicesAreSharedAcrossGraphAsync()
    {
        // Phase 2 DI regression: validates that singleton services are shared
        // across all components that depend on them.
        // Uses nested accessor paths (same as existing VerifyHostGraphSharesWorkspaceStateAcrossDispatcherAndCoordinatorsAsync)
        // to reach shared state through the nested service composition.
        await using var host = HostGraphHarness.CreateStdio("singleton_services_shared");

        // WorkspaceState shared via nested services: acquisitionService -> workspaceState
        var sessionAcquisitionService = GetRequiredFieldValue(host.EditorSessionCoordinator!, "_acquisitionService");
        var sessionWorkspace = GetRequiredFieldValue(sessionAcquisitionService, "_workspaceState");
        AssertReferenceEquals(host.WorkspaceState!, sessionWorkspace, "session acquisition -> workspace state");

        // Lifecycle coordinator -> statusService/actionService -> workspaceState
        var lifecycleStatusService = GetRequiredFieldValue(host.EditorLifecycleCoordinator!, "_statusService");
        var lifecycleActionService = GetRequiredFieldValue(host.EditorLifecycleCoordinator!, "_actionService");
        var lifecycleStatusWorkspace = GetRequiredFieldValue(lifecycleStatusService, "_workspaceState");
        var lifecycleActionWorkspace = GetRequiredFieldValue(lifecycleActionService, "_workspaceState");
        AssertReferenceEquals(host.WorkspaceState!, lifecycleStatusWorkspace, "lifecycle status -> workspace state");
        AssertReferenceEquals(host.WorkspaceState!, lifecycleActionWorkspace, "lifecycle action -> workspace state");

        // Dispatcher -> editorToolForwarder -> hostSessionPayloadFactory -> workspaceState
        var forwarder = GetRequiredFieldValue(host.Dispatcher!, "_editorToolForwarder");
        var payloadFactory = GetRequiredFieldValue(forwarder, "_hostSessionPayloadFactory");
        var dispatcherWorkspace = GetRequiredFieldValue(payloadFactory, "_workspaceState");
        AssertReferenceEquals(host.WorkspaceState!, dispatcherWorkspace, "dispatcher payload factory -> workspace state");

        // EditorSessions shared via nested services: acquisitionService -> editorSessions
        var sessionAcquisitionSessions = GetRequiredFieldValue(sessionAcquisitionService, "_editorSessions");
        AssertReferenceEquals(host.EditorSessions!, sessionAcquisitionSessions, "session acquisition -> editor sessions");

        // Attach server -> sessions (direct field access)
        var attachServerSessions = GetRequiredFieldValue(host.AttachServer!, "_sessions");
        AssertReferenceEquals(host.EditorSessions!, attachServerSessions, "attach server -> editor sessions");

        // Registry shared via nested services: acquisitionService -> registry
        var sessionAcquisitionRegistry = GetRequiredFieldValue(sessionAcquisitionService, "_registry");
        AssertReferenceEquals(host.Registry, sessionAcquisitionRegistry, "session acquisition -> registry");
    }

    public static async Task VerifyAttachOnlyGraphIsMinimalAsync()
    {
        // Phase 2 DI regression: validates that attach-only mode builds
        // a minimal graph (configuration + registry + sessions + attach server only).
        await using var host = HostGraphHarness.CreateAttachOnly("attach_only_graph_minimal");

        // Attach-only should have configuration, registry, editor sessions, and attach server
        if (host.Configuration is null)
        {
            throw new InvalidOperationException("Configuration service should exist in attach-only composition.");
        }

        if (host.Registry is null)
        {
            throw new InvalidOperationException("Registry service should exist in attach-only composition.");
        }

        if (host.EditorSessions is null)
        {
            throw new InvalidOperationException("Editor sessions service should exist in attach-only composition.");
        }

        if (host.AttachServer is null)
        {
            throw new InvalidOperationException("Attach server should exist in attach-only composition.");
        }

        // Attach-only should NOT have workspace state, coordinators, or dispatcher
        if (host.WorkspaceState is not null)
        {
            throw new InvalidOperationException("Workspace state should NOT exist in attach-only composition.");
        }

        if (host.EditorSessionCoordinator is not null)
        {
            throw new InvalidOperationException("Session coordinator should NOT exist in attach-only composition.");
        }

        if (host.EditorLifecycleCoordinator is not null)
        {
            throw new InvalidOperationException("Lifecycle coordinator should NOT exist in attach-only composition.");
        }

        if (host.Dispatcher is not null)
        {
            throw new InvalidOperationException("Dispatcher should NOT exist in attach-only composition.");
        }
    }

    public static async Task VerifyHostCompositionRootDisposesCleanlyAsync()
    {
        var previousCentralHome = Environment.GetEnvironmentVariable("GODOT_DOTNET_MCP_CENTRAL_HOME");
        var harness = ContractHarness.Create("host_composition_root_disposes_cleanly");
        var tempRoot = (string)GetRequiredFieldValue(harness, "_tempRoot");
        var attachPort = harness.AttachPort;
        var disposed = false;

        try
        {
            await harness.RegisterProjectAsync();
            await harness.DisposeAsync();
            disposed = true;

            var currentCentralHome = Environment.GetEnvironmentVariable("GODOT_DOTNET_MCP_CENTRAL_HOME");
            if (!string.Equals(previousCentralHome, currentCentralHome, StringComparison.Ordinal))
            {
                throw new InvalidOperationException("Composition root disposal did not restore GODOT_DOTNET_MCP_CENTRAL_HOME.");
            }

            if (Directory.Exists(tempRoot))
            {
                throw new InvalidOperationException("Composition root disposal should cleanup temporary host artifacts.");
            }

            using var listener = new TcpListener(IPAddress.Loopback, attachPort);
            listener.Start();
            listener.Stop();
        }
        finally
        {
            if (!disposed)
            {
                await harness.DisposeAsync();
            }
        }
    }

    private static void AssertReferenceEquals(object expected, object actual, string description)
    {
        if (!ReferenceEquals(expected, actual))
        {
            throw new InvalidOperationException($"Expected shared instance for {description}, but references differ.");
        }
    }

    private static object GetRequiredFieldValue(object target, string fieldName)
    {
        var field = target.GetType().GetField(fieldName, BindingFlags.Instance | BindingFlags.NonPublic)
                    ?? throw new InvalidOperationException($"Field '{fieldName}' not found on {target.GetType().Name}.");
        return field.GetValue(target)
               ?? throw new InvalidOperationException($"Field '{fieldName}' on {target.GetType().Name} is null.");
    }

    private static int GetFreeTcpPort()
    {
        using var listener = new TcpListener(IPAddress.Loopback, 0);
        listener.Start();
        var endpoint = (IPEndPoint)listener.LocalEndpoint;
        return endpoint.Port;
    }

    private sealed class HostGraphHarness : IAsyncDisposable
    {
        private readonly string _tempRoot;
        private readonly string? _previousCentralHome;
        private readonly CancellationTokenSource _lifetime;
        private readonly CentralServerRuntimeGraph _runtimeGraph;

        private HostGraphHarness(
            string tempRoot,
            string? previousCentralHome,
            CancellationTokenSource lifetime,
            CentralServerRuntimeGraph runtimeGraph,
            string attachHost,
            int attachPort,
            EditorAttachEndpoint attachEndpoint,
            CentralConfigurationService configuration,
            ProjectRegistryService registry,
            EditorSessionService editorSessions,
            EditorAttachHttpServer attachServer,
            CentralWorkspaceState? workspaceState,
            EditorSessionCoordinator? editorSessionCoordinator,
            EditorLifecycleCoordinator? editorLifecycleCoordinator,
            CentralToolDispatcher? dispatcher,
            EditorProxyService? editorProxy,
            GodotProjectManagerProvider? godotProjectManager)
        {
            _tempRoot = tempRoot;
            _previousCentralHome = previousCentralHome;
            _lifetime = lifetime;
            _runtimeGraph = runtimeGraph;
            AttachHost = attachHost;
            AttachPort = attachPort;
            AttachEndpoint = attachEndpoint;
            Configuration = configuration;
            Registry = registry;
            EditorSessions = editorSessions;
            AttachServer = attachServer;
            WorkspaceState = workspaceState;
            EditorSessionCoordinator = editorSessionCoordinator;
            EditorLifecycleCoordinator = editorLifecycleCoordinator;
            Dispatcher = dispatcher;
            EditorProxy = editorProxy;
            GodotProjectManager = godotProjectManager;
            ProjectRoot = Path.Combine(tempRoot, "project");
        }

        public string ProjectRoot { get; }

        public string AttachHost { get; }

        public int AttachPort { get; }

        public EditorAttachEndpoint AttachEndpoint { get; }

        public CentralConfigurationService Configuration { get; }

        public ProjectRegistryService Registry { get; }

        public EditorSessionService EditorSessions { get; }

        public EditorAttachHttpServer AttachServer { get; }

        public CentralWorkspaceState? WorkspaceState { get; }

        public EditorSessionCoordinator? EditorSessionCoordinator { get; }

        public EditorLifecycleCoordinator? EditorLifecycleCoordinator { get; }

        public CentralToolDispatcher? Dispatcher { get; }

        public EditorProxyService? EditorProxy { get; }

        public GodotProjectManagerProvider? GodotProjectManager { get; }

        public static HostGraphHarness CreateStdio(string name, string[]? args = null)
        {
            var tempRoot = CreateTempRoot(name);
            var previousCentralHome = PrepareCentralHome(tempRoot);

            var configuration = new CentralConfigurationService();
            var attachEndpoint = ResolveAttachEndpoint(args, configuration);

            var lifetime = new CancellationTokenSource();
            var bootstrapAttachServer = new EditorAttachHttpServer(
                attachEndpoint.Host,
                attachEndpoint.Port,
                new EditorSessionService(new ProjectRegistryService()),
                TextWriter.Null,
                () =>
                {
                    lifetime.Cancel();
                    return Task.CompletedTask;
                });
            var runtimeGraph = CentralServerComposition.BuildStdioGraph(attachEndpoint, bootstrapAttachServer, null);
            var attachServer = new EditorAttachHttpServer(
                attachEndpoint.Host,
                attachEndpoint.Port,
                runtimeGraph.EditorSessions,
                TextWriter.Null,
                () =>
                {
                    lifetime.Cancel();
                    return Task.CompletedTask;
                });
            runtimeGraph = runtimeGraph with { AttachServer = attachServer };
            bootstrapAttachServer.DisposeAsync().AsTask().GetAwaiter().GetResult();

            var harness = new HostGraphHarness(
                tempRoot,
                previousCentralHome,
                lifetime,
                runtimeGraph,
                attachEndpoint.Host,
                attachEndpoint.Port,
                attachEndpoint,
                runtimeGraph.Configuration,
                runtimeGraph.Registry,
                runtimeGraph.EditorSessions,
                attachServer,
                runtimeGraph.WorkspaceState,
                runtimeGraph.EditorSessionCoordinator,
                runtimeGraph.EditorLifecycleCoordinator,
                runtimeGraph.Dispatcher,
                runtimeGraph.EditorProxy,
                runtimeGraph.GodotProjectManager);
            harness.CreateProjectFixture();
            attachServer.Start(lifetime.Token);
            return harness;
        }

        public static HostGraphHarness CreateAttachOnly(string name, string[]? args = null)
        {
            var tempRoot = CreateTempRoot(name);
            var previousCentralHome = PrepareCentralHome(tempRoot);

            var configuration = new CentralConfigurationService();
            var attachEndpoint = ResolveAttachEndpoint(args, configuration);
            var lifetime = new CancellationTokenSource();
            var bootstrapAttachServer = new EditorAttachHttpServer(
                attachEndpoint.Host,
                attachEndpoint.Port,
                new EditorSessionService(new ProjectRegistryService()),
                TextWriter.Null,
                () =>
                {
                    lifetime.Cancel();
                    return Task.CompletedTask;
                });
            var runtimeGraph = CentralServerComposition.BuildAttachOnlyGraph(attachEndpoint, bootstrapAttachServer, null);
            var attachServer = new EditorAttachHttpServer(
                attachEndpoint.Host,
                attachEndpoint.Port,
                runtimeGraph.EditorSessions,
                TextWriter.Null,
                () =>
                {
                    lifetime.Cancel();
                    return Task.CompletedTask;
                });
            runtimeGraph = runtimeGraph with { AttachServer = attachServer };
            bootstrapAttachServer.DisposeAsync().AsTask().GetAwaiter().GetResult();

            var harness = new HostGraphHarness(
                tempRoot,
                previousCentralHome,
                lifetime,
                runtimeGraph,
                attachEndpoint.Host,
                attachEndpoint.Port,
                attachEndpoint,
                runtimeGraph.Configuration,
                runtimeGraph.Registry,
                runtimeGraph.EditorSessions,
                attachServer,
                workspaceState: null,
                editorSessionCoordinator: null,
                editorLifecycleCoordinator: null,
                dispatcher: null,
                editorProxy: null,
                godotProjectManager: null);
            harness.CreateProjectFixture();
            attachServer.Start(lifetime.Token);
            return harness;
        }

        public async Task<string> RegisterProjectAsync()
        {
            if (Dispatcher is null)
            {
                throw new InvalidOperationException("Dispatcher is not available for attach-only composition root.");
            }

            var response = await Dispatcher.ExecuteAsync(
                "workspace_project_register",
                SerializeToElement(new { path = ProjectRoot }),
                CancellationToken.None);
            EnsureSuccess(response, "workspace_project_register");
            var payload = SerializeToElement(response.StructuredContent);
            return payload.GetProperty("project").GetProperty("projectId").GetString()
                   ?? throw new InvalidOperationException("Registered project payload did not include projectId.");
        }

        public async ValueTask DisposeAsync()
        {
            _lifetime.Cancel();
            await AttachServer.DisposeAsync();
            _runtimeGraph.Dispose();
            _lifetime.Dispose();
            Environment.SetEnvironmentVariable("GODOT_DOTNET_MCP_CENTRAL_HOME", _previousCentralHome);

            try
            {
                if (Directory.Exists(_tempRoot))
                {
                    Directory.Delete(_tempRoot, recursive: true);
                }
            }
            catch
            {
            }
        }

        private void CreateProjectFixture()
        {
            Directory.CreateDirectory(ProjectRoot);
            File.WriteAllText(
                Path.Combine(ProjectRoot, "project.godot"),
                """
                ; Engine configuration file.
                config_version=5

                [application]
                config/name="Host Composition Root Contracts"
                """,
                new UTF8Encoding(encoderShouldEmitUTF8Identifier: false));
        }

        private static string CreateTempRoot(string name)
        {
            var repoRoot = ResolveRepoRoot();
            var tempRoot = Path.Combine(repoRoot, ".tmp", "host_contracts", $"{name}_{Guid.NewGuid():N}");
            Directory.CreateDirectory(tempRoot);
            return tempRoot;
        }

        private static string? PrepareCentralHome(string tempRoot)
        {
            var previousCentralHome = Environment.GetEnvironmentVariable("GODOT_DOTNET_MCP_CENTRAL_HOME");
            var centralHome = Path.Combine(tempRoot, "CentralHome");
            Directory.CreateDirectory(centralHome);
            Environment.SetEnvironmentVariable("GODOT_DOTNET_MCP_CENTRAL_HOME", centralHome);
            return previousCentralHome;
        }

        private static EditorAttachEndpoint ResolveAttachEndpoint(string[]? args, CentralConfigurationService configuration)
        {
            var method = typeof(CentralServerApplication).GetMethod(
                             "ResolveAttachEndpoint",
                             BindingFlags.NonPublic | BindingFlags.Static)
                         ?? throw new InvalidOperationException("Could not find CentralServerApplication.ResolveAttachEndpoint.");
            var endpoint = method.Invoke(null, [args ?? [], configuration]) as EditorAttachEndpoint;
            return endpoint
                   ?? throw new InvalidOperationException("CentralServerApplication.ResolveAttachEndpoint returned null.");
        }

        private static string ResolveRepoRoot()
        {
            var candidates = new[]
            {
                Directory.GetCurrentDirectory(),
                AppContext.BaseDirectory,
            };

            foreach (var candidate in candidates)
            {
                var resolved = TryResolveRepoRoot(candidate);
                if (!string.IsNullOrWhiteSpace(resolved))
                {
                    return resolved;
                }
            }

            throw new InvalidOperationException("Could not resolve repository root for host composition root tests.");
        }

        private static string? TryResolveRepoRoot(string startPath)
        {
            var current = new DirectoryInfo(startPath);
            while (current is not null)
            {
                if (Directory.Exists(Path.Combine(current.FullName, "central_server"))
                    && Directory.Exists(Path.Combine(current.FullName, "tests")))
                {
                    return current.FullName;
                }

                current = current.Parent;
            }

            return null;
        }
    }
}
