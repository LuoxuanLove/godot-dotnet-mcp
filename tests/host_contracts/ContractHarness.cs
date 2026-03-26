using System.Text;
using System.Text.Json;
using GodotDotnetMcp.CentralServer;
using static ContractAssertions;
using static ContractHttpSupport;
using static ContractPayloadSupport;

internal sealed class ContractHarness : IAsyncDisposable
{
    private readonly string? _previousCentralHome;
    private readonly string _tempRoot;
    private readonly EditorProxyService _editorProxy;
    private readonly CancellationTokenSource _lifetime = new();
    private readonly EditorAttachHttpServer _attachServer;

    private ContractHarness(
        string tempRoot,
        string? previousCentralHome,
        EditorProxyService editorProxy,
        EditorAttachHttpServer attachServer,
        ProjectRegistryService registry,
        EditorSessionService editorSessions,
        CentralToolDispatcher dispatcher,
        string attachHost,
        int attachPort)
    {
        _tempRoot = tempRoot;
        _previousCentralHome = previousCentralHome;
        _editorProxy = editorProxy;
        _attachServer = attachServer;
        Registry = registry;
        EditorSessions = editorSessions;
        Dispatcher = dispatcher;
        AttachHost = attachHost;
        AttachPort = attachPort;
        ProjectRoot = Path.Combine(tempRoot, "project");
    }

    public string ProjectRoot { get; }

    public string AttachHost { get; }

    public int AttachPort { get; }

    public ProjectRegistryService Registry { get; }

    public EditorSessionService EditorSessions { get; }

    public CentralToolDispatcher Dispatcher { get; }

    public static ContractHarness Create(string name)
    {
        var repoRoot = ResolveRepoRoot();
        var tempRoot = Path.Combine(repoRoot, ".tmp", "host_contracts", $"{name}_{Guid.NewGuid():N}");
        Directory.CreateDirectory(tempRoot);

        var previousCentralHome = Environment.GetEnvironmentVariable("GODOT_DOTNET_MCP_CENTRAL_HOME");
        var centralHome = Path.Combine(tempRoot, "CentralHome");
        Directory.CreateDirectory(centralHome);
        Environment.SetEnvironmentVariable("GODOT_DOTNET_MCP_CENTRAL_HOME", centralHome);

        var configuration = new CentralConfigurationService();
        var editorProcesses = new EditorProcessService();
        var godotInstallations = new GodotInstallationService();
        var godotProjectManager = new GodotProjectManagerProvider(configuration);
        var registry = new ProjectRegistryService();
        var editorSessions = new EditorSessionService(registry);
        var editorProxy = new EditorProxyService();
        var workspaceState = new CentralWorkspaceState();
        var attachHost = "127.0.0.1";
        var attachPort = GetFreeTcpPort();
        var attachEndpoint = new EditorAttachEndpoint(attachHost, attachPort);
        var editorSessionCoordinator = new EditorSessionCoordinator(configuration, editorProcesses, editorSessions, godotInstallations, registry, workspaceState, attachEndpoint);
        var editorLifecycleCoordinator = new EditorLifecycleCoordinator(configuration, editorProcesses, editorProxy, editorSessionCoordinator, editorSessions, registry, workspaceState);
        var dispatcher = new CentralToolDispatcher(configuration, editorProxy, editorProcesses, editorLifecycleCoordinator, editorSessionCoordinator, editorSessions, godotInstallations, godotProjectManager, registry, workspaceState);
        var attachServer = new EditorAttachHttpServer(attachHost, attachPort, editorSessions, TextWriter.Null);

        var harness = new ContractHarness(tempRoot, previousCentralHome, editorProxy, attachServer, registry, editorSessions, dispatcher, attachHost, attachPort);
        harness.CreateProjectFixture();
        attachServer.Start(harness._lifetime.Token);
        return harness;
    }

    public async Task<string> RegisterProjectAsync()
    {
        var response = await Dispatcher.ExecuteAsync(
            "workspace_project_register",
            SerializeToElement(new { path = ProjectRoot }),
            CancellationToken.None);
        EnsureSuccess(response, "workspace_project_register");

        var payload = SerializeToElement(response.StructuredContent);
        return payload.GetProperty("project").GetProperty("projectId").GetString()
               ?? throw new InvalidOperationException("Registered project payload did not include projectId.");
    }

    public async Task<MockEditorMcpServer> AttachMockEditorAsync(
        string projectId,
        string sessionId,
        string[] capabilities,
        Action<MockEditorMcpServer>? configure = null)
    {
        var mockPort = GetFreeTcpPort();
        var mockServer = new MockEditorMcpServer("127.0.0.1", mockPort, AttachHost, AttachPort, ProjectRoot);
        configure?.Invoke(mockServer);
        mockServer.SetSession(projectId, sessionId, capabilities);
        mockServer.Start(_lifetime.Token);

        var attachResponse = await SendJsonRequestAsync(
            AttachHost,
            AttachPort,
            "POST",
            "/api/editor/attach",
            BuildMockAttachRequest(projectId, ProjectRoot, sessionId, capabilities, mockPort),
            CancellationToken.None);

        if (!attachResponse.TryGetProperty("success", out var successElement)
            || successElement.ValueKind != JsonValueKind.True)
        {
            await mockServer.DisposeAsync();
            throw new InvalidOperationException("Mock editor attach did not return success=true.");
        }

        return mockServer;
    }

    public async ValueTask DisposeAsync()
    {
        _lifetime.Cancel();
        await _attachServer.DisposeAsync();
        _lifetime.Dispose();
        _editorProxy.Dispose();
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
            config/name="Host Contracts"
            """,
            new UTF8Encoding(encoderShouldEmitUTF8Identifier: false));
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

        throw new InvalidOperationException("Could not resolve repository root for host contract tests.");
    }

    private static string? TryResolveRepoRoot(string startPath)
    {
        var current = new DirectoryInfo(startPath);
        while (current is not null)
        {
            if (Directory.Exists(Path.Combine(current.FullName, "central_server"))
                && Directory.Exists(Path.Combine(current.FullName, "addons")))
            {
                return current.FullName;
            }

            current = current.Parent;
        }

        return null;
    }
}
