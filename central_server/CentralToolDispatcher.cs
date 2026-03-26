using System.Text.Json;
using GodotDotnetMcp.HostShared;

namespace GodotDotnetMcp.CentralServer;

internal sealed class CentralToolDispatcher
{
    private readonly CentralConfigurationService _configuration;
    private readonly EditorProxyService _editorProxy;
    private readonly EditorLifecycleCoordinator _editorLifecycleCoordinator;
    private readonly EditorSessionCoordinator _editorSessionCoordinator;
    private readonly EditorSessionService _editorSessions;
    private readonly GodotInstallationService _godotInstallations;
    private readonly GodotProjectManagerProvider _godotProjectManager;
    private readonly ProjectRegistryService _registry;
    private readonly CentralWorkspaceState _workspaceState;
    private readonly CentralToolHandlerRegistry _handlers;
    private readonly CentralHostSessionPayloadFactory _hostSessionPayloadFactory;

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
        _configuration = configuration;
        _editorProxy = editorProxy;
        _editorLifecycleCoordinator = editorLifecycleCoordinator;
        _editorSessionCoordinator = editorSessionCoordinator;
        _editorSessions = editorSessions;
        _godotInstallations = godotInstallations;
        _godotProjectManager = godotProjectManager;
        _registry = registry;
        _workspaceState = workspaceState;
        _hostSessionPayloadFactory = new CentralHostSessionPayloadFactory(_editorLifecycleCoordinator, _editorSessionCoordinator, _workspaceState);
        _handlers = BuildHandlerRegistry();
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
                ? await ExecuteSystemToolAsync(toolName, arguments, cancellationToken)
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

    private CentralToolHandlerRegistry BuildHandlerRegistry()
    {
        return new CentralToolHandlerRegistry()
            .Register("workspace_project_list", (arguments, cancellationToken) =>
            {
                cancellationToken.ThrowIfCancellationRequested();
                return Task.FromResult(ListProjects(arguments));
            })
            .Register("workspace_project_register", (arguments, cancellationToken) =>
            {
                cancellationToken.ThrowIfCancellationRequested();
                return Task.FromResult(RegisterProject(arguments));
            })
            .Register("workspace_project_remove", (arguments, cancellationToken) =>
            {
                cancellationToken.ThrowIfCancellationRequested();
                return Task.FromResult(RemoveProject(arguments));
            })
            .Register("workspace_project_select", (arguments, cancellationToken) =>
            {
                cancellationToken.ThrowIfCancellationRequested();
                return Task.FromResult(SelectProject(arguments));
            })
            .Register("workspace_project_status", GetStatusAsync)
            .Register("workspace_project_rescan", (arguments, cancellationToken) =>
            {
                cancellationToken.ThrowIfCancellationRequested();
                return Task.FromResult(RescanProjects(arguments));
            })
            .Register("workspace_editor_session_list", (arguments, cancellationToken) =>
            {
                cancellationToken.ThrowIfCancellationRequested();
                return Task.FromResult(ListEditorSessions(arguments));
            })
            .Register("workspace_project_set_godot_path", (arguments, cancellationToken) =>
            {
                cancellationToken.ThrowIfCancellationRequested();
                return Task.FromResult(SetProjectGodotPath(arguments));
            })
            .Register("workspace_project_open_editor", OpenProjectEditorAsync)
            .Register("workspace_project_close_editor", CloseProjectEditorAsync)
            .Register("workspace_project_restart_editor", RestartProjectEditorAsync)
            .Register("workspace_godot_installation_list", (arguments, cancellationToken) =>
            {
                cancellationToken.ThrowIfCancellationRequested();
                return Task.FromResult(ListGodotInstallations(arguments));
            })
            .Register("workspace_godot_set_default_executable", (arguments, cancellationToken) =>
            {
                cancellationToken.ThrowIfCancellationRequested();
                return Task.FromResult(SetDefaultGodotExecutable(arguments));
            })
            .Register("workspace_godot_manager_list_projects", (arguments, cancellationToken) =>
            {
                cancellationToken.ThrowIfCancellationRequested();
                return Task.FromResult(ListGodotManagerProjects(arguments));
            })
            .Register("workspace_godot_manager_get_status", (arguments, cancellationToken) =>
            {
                cancellationToken.ThrowIfCancellationRequested();
                return Task.FromResult(GetGodotManagerStatus(arguments));
            })
            .Register("workspace_godot_manager_import_projects", (arguments, cancellationToken) =>
            {
                cancellationToken.ThrowIfCancellationRequested();
                return Task.FromResult(ImportGodotManagerProjects(arguments));
            });
    }

    private CentralToolCallResponse ListProjects(JsonElement _)
    {
        var projects = _registry.ListProjects();
        var workspaceState = _workspaceState.Snapshot();
        return CentralToolCallResponse.Success(new
        {
            activeProjectId = workspaceState.ActiveProjectId,
            activeEditorSessionId = workspaceState.ActiveEditorSessionId,
            projects,
            count = projects.Count,
        });
    }

    private CentralToolCallResponse RegisterProject(JsonElement arguments)
    {
        var projectPath = CentralArgumentReader.GetRequiredString(arguments, "path");
        var source = CentralArgumentReader.GetOptionalString(arguments, "source") ?? "manual";
        var project = _registry.RegisterProject(projectPath, source);
        var workspaceState = _workspaceState.Snapshot();
        return CentralToolCallResponse.Success(new
        {
            registered = true,
            project,
            activeProjectId = workspaceState.ActiveProjectId,
            activeEditorSessionId = workspaceState.ActiveEditorSessionId,
        });
    }

    private CentralToolCallResponse RemoveProject(JsonElement arguments)
    {
        var projectId = CentralArgumentReader.GetOptionalString(arguments, "projectId");
        var path = CentralArgumentReader.GetOptionalString(arguments, "path");
        if (string.IsNullOrWhiteSpace(projectId) && string.IsNullOrWhiteSpace(path))
        {
            throw new CentralToolException("workspace_project_remove requires either projectId or path.");
        }

        if (!_registry.RemoveProject(projectId, path, out var removedProject) || removedProject is null)
        {
            throw new CentralToolException("Registered project not found.");
        }

        if (string.Equals(_workspaceState.ActiveProjectId, removedProject.ProjectId, StringComparison.OrdinalIgnoreCase))
        {
            _workspaceState.ClearActiveProject();
        }

        var activeEditorSession = _editorSessions.GetStatusBySessionId(_workspaceState.ActiveEditorSessionId);
        if (activeEditorSession is not null
            && string.Equals(activeEditorSession.ProjectId, removedProject.ProjectId, StringComparison.OrdinalIgnoreCase))
        {
            _workspaceState.ClearActiveEditorSession();
        }

        var workspaceState = _workspaceState.Snapshot();
        return CentralToolCallResponse.Success(new
        {
            removed = true,
            project = removedProject,
            activeProjectId = workspaceState.ActiveProjectId,
            activeEditorSessionId = workspaceState.ActiveEditorSessionId,
        });
    }

    private CentralToolCallResponse SelectProject(JsonElement arguments)
    {
        var projectId = CentralArgumentReader.GetOptionalString(arguments, "projectId");
        var path = CentralArgumentReader.GetOptionalString(arguments, "path");
        if (string.IsNullOrWhiteSpace(projectId) && string.IsNullOrWhiteSpace(path))
        {
            throw new CentralToolException("workspace_project_select requires either projectId or path.");
        }

        var project = _registry.ResolveProject(projectId, path);
        if (project is null)
        {
            throw new CentralToolException("Registered project not found.");
        }

        _workspaceState.SetActiveProject(project.ProjectId);
        var workspaceState = _workspaceState.Snapshot();
        return CentralToolCallResponse.Success(new
        {
            selected = true,
            activeProjectId = workspaceState.ActiveProjectId,
            activeEditorSessionId = workspaceState.ActiveEditorSessionId,
            project,
        });
    }

    private async Task<CentralToolCallResponse> GetStatusAsync(JsonElement arguments, CancellationToken cancellationToken)
    {
        var projectId = CentralArgumentReader.GetOptionalString(arguments, "projectId");
        var path = CentralArgumentReader.GetOptionalString(arguments, "path");
        var snapshot = await _editorLifecycleCoordinator.GetProjectStatusAsync(projectId, path, cancellationToken);
        return snapshot.Success
            ? CentralToolCallResponse.Success(snapshot.ToPayload())
            : CentralToolCallResponse.Error(snapshot.Message, snapshot.ToPayload());
    }

    private CentralToolCallResponse RescanProjects(JsonElement arguments)
    {
        var roots = CentralArgumentReader.GetStringArray(arguments, "roots");
        if (roots.Count == 0)
        {
            throw new CentralToolException("workspace_project_rescan requires at least one root.");
        }

        var importDiscovered = CentralArgumentReader.GetBooleanOrDefault(arguments, "importDiscovered", false);
        var result = _registry.RescanProjects(roots, importDiscovered);
        var workspaceState = _workspaceState.Snapshot();
        return CentralToolCallResponse.Success(new
        {
            importDiscovered,
            result.Roots,
            result.DiscoveredProjectRoots,
            result.ImportedProjects,
            result.DuplicateProjectRoots,
            activeProjectId = workspaceState.ActiveProjectId,
            activeEditorSessionId = workspaceState.ActiveEditorSessionId,
        });
    }

    private CentralToolCallResponse ListEditorSessions(JsonElement _)
    {
        var sessions = _editorSessions.ListSessions();
        var workspaceState = _workspaceState.Snapshot();
        return CentralToolCallResponse.Success(new
        {
            count = sessions.Count,
            sessions,
            activeProjectId = workspaceState.ActiveProjectId,
            activeEditorSessionId = workspaceState.ActiveEditorSessionId,
        });
    }

    private CentralToolCallResponse SetProjectGodotPath(JsonElement arguments)
    {
        var projectId = CentralArgumentReader.GetRequiredString(arguments, "projectId");
        var executablePath = CentralArgumentReader.GetRequiredString(arguments, "executablePath");
        var project = _registry.AssignGodotExecutablePath(projectId, executablePath);
        return CentralToolCallResponse.Success(new
        {
            project,
        });
    }

    private async Task<CentralToolCallResponse> OpenProjectEditorAsync(JsonElement arguments, CancellationToken cancellationToken)
    {
        var projectId = CentralArgumentReader.GetOptionalString(arguments, "projectId");
        var path = CentralArgumentReader.GetOptionalString(arguments, "path");
        var explicitExecutablePath = CentralArgumentReader.GetOptionalString(arguments, "executablePath") ?? string.Empty;
        var attachTimeoutMs = CentralArgumentReader.GetOptionalPositiveInt(arguments, "attachTimeoutMs");

        var coordination = await _editorSessionCoordinator.EnsureHttpReadySessionAsync(
            "workspace_project_open_editor",
            projectId,
            path,
            autoLaunchEditor: true,
            attachTimeoutMs,
            explicitExecutablePath,
            "workspace_open_editor",
            cancellationToken);

        if (!coordination.Success || coordination.Project is null || coordination.Session is null)
        {
            return CentralToolCallResponse.Error(coordination.Message, _hostSessionPayloadFactory.BuildFailurePayload(coordination, "workspace_project_open_editor"));
        }

        var centralHostSession = _hostSessionPayloadFactory.Build(
            coordination,
            coordination.Session is null ? string.Empty : $"http://{coordination.Session.ServerHost}:{coordination.Session.ServerPort ?? 0}/mcp",
            "workspace_project_open_editor");
        var editorLifecycle = coordination.Project is null
            ? null
            : _editorLifecycleCoordinator.BuildLifecycleSummary(
                "workspace_project_open_editor",
                coordination.Project,
                coordination.Session,
                _editorLifecycleCoordinator.GetEffectiveProcessStatus(coordination.Project.ProjectId, coordination.Project.ProjectRoot, coordination.Session),
                _hostSessionPayloadFactory.GetResolution(coordination));
        return CentralToolCallResponse.Success(new
        {
            project = coordination.Project,
            editorSession = coordination.Session,
            editorLifecycle,
            centralHostSession,
        });
    }

    private async Task<CentralToolCallResponse> CloseProjectEditorAsync(JsonElement arguments, CancellationToken cancellationToken)
    {
        var result = await _editorLifecycleCoordinator.CloseEditorAsync(
            CentralArgumentReader.GetOptionalString(arguments, "projectId"),
            CentralArgumentReader.GetOptionalString(arguments, "path"),
            CentralArgumentReader.GetBooleanOrDefault(arguments, "save", false),
            CentralArgumentReader.GetBooleanOrDefault(arguments, "force", false),
            CentralArgumentReader.GetOptionalPositiveInt(arguments, "shutdownTimeoutMs"),
            cancellationToken);

        return result.Success
            ? CentralToolCallResponse.Success(result.ToPayload())
            : CentralToolCallResponse.Error(result.Message, result.ToPayload());
    }

    private async Task<CentralToolCallResponse> RestartProjectEditorAsync(JsonElement arguments, CancellationToken cancellationToken)
    {
        var result = await _editorLifecycleCoordinator.RestartEditorAsync(
            CentralArgumentReader.GetOptionalString(arguments, "projectId"),
            CentralArgumentReader.GetOptionalString(arguments, "path"),
            CentralArgumentReader.GetBooleanOrDefault(arguments, "save", false),
            CentralArgumentReader.GetBooleanOrDefault(arguments, "force", false),
            CentralArgumentReader.GetOptionalPositiveInt(arguments, "shutdownTimeoutMs"),
            CentralArgumentReader.GetOptionalPositiveInt(arguments, "attachTimeoutMs"),
            cancellationToken);

        return result.Success
            ? CentralToolCallResponse.Success(result.ToPayload())
            : CentralToolCallResponse.Error(result.Message, result.ToPayload());
    }

    private CentralToolCallResponse ListGodotInstallations(JsonElement _)
    {
        var candidates = _godotInstallations.ListCandidates();
        return CentralToolCallResponse.Success(new
        {
            count = candidates.Count,
            candidates,
            configuration = _configuration.BuildStatus(),
        });
    }

    private CentralToolCallResponse SetDefaultGodotExecutable(JsonElement arguments)
    {
        var executablePath = CentralArgumentReader.GetRequiredString(arguments, "executablePath");
        var configuration = _configuration.SetDefaultGodotExecutablePath(executablePath);
        return CentralToolCallResponse.Success(new
        {
            configuration,
        });
    }

    private CentralToolCallResponse ListGodotManagerProjects(JsonElement _)
    {
        var candidates = _godotProjectManager.ListProjects(_registry.GetRegisteredProjectRoots());
        return CentralToolCallResponse.Success(new
        {
            count = candidates.Count,
            candidates,
        });
    }

    private CentralToolCallResponse GetGodotManagerStatus(JsonElement _)
    {
        var status = _godotProjectManager.GetStatus(_registry.GetRegisteredProjectRoots());
        return CentralToolCallResponse.Success(new
        {
            status,
            configuration = _configuration.BuildStatus(),
        });
    }

    private CentralToolCallResponse ImportGodotManagerProjects(JsonElement arguments)
    {
        var paths = CentralArgumentReader.GetStringArray(arguments, "paths");
        if (paths.Count == 0)
        {
            throw new CentralToolException("workspace_godot_manager_import_projects requires at least one path.");
        }

        var imported = new List<ProjectRegistryService.RegisteredProject>();
        var duplicates = new List<string>();
        foreach (var path in paths)
        {
            var existing = _registry.ResolveProject(null, path);
            if (existing is not null)
            {
                duplicates.Add(existing.ProjectRoot);
                continue;
            }

            imported.Add(_registry.RegisterProject(path, "godot_manager"));
        }

        return CentralToolCallResponse.Success(new
        {
            importedCount = imported.Count,
            duplicateCount = duplicates.Count,
            importedProjects = imported,
            duplicateProjectRoots = duplicates,
        });
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

    private async Task<CentralToolCallResponse> ExecuteSystemToolAsync(
        string toolName,
        JsonElement arguments,
        CancellationToken cancellationToken)
    {
        var projectId = CentralArgumentReader.GetOptionalString(arguments, "projectId");
        var projectPath = CentralArgumentReader.GetOptionalString(arguments, "projectPath");
        var autoLaunchEditor = CentralArgumentReader.GetBooleanOrDefault(arguments, "autoLaunchEditor", true);
        var attachTimeoutMs = CentralArgumentReader.GetOptionalPositiveInt(arguments, "editorAttachTimeoutMs");
        return await ForwardEditorToolDirectAsync(
            toolName,
            arguments,
            projectId,
            projectPath,
            autoLaunchEditor,
            attachTimeoutMs,
            cancellationToken);
    }

    private async Task<CentralToolCallResponse> ForwardEditorToolDirectAsync(
        string toolName,
        JsonElement forwardedArguments,
        string? projectId,
        string? projectPath,
        bool autoLaunchEditor,
        int? attachTimeoutMs,
        CancellationToken cancellationToken)
    {
        var coordination = await _editorSessionCoordinator.EnsureHttpReadySessionAsync(
            toolName,
            projectId,
            projectPath,
            autoLaunchEditor,
            attachTimeoutMs,
            explicitExecutablePath: null,
            launchReason: "system_auto_launch",
            cancellationToken: cancellationToken);

        if (!coordination.Success || coordination.Project is null || coordination.Session is null)
        {
            return CentralToolCallResponse.Error(coordination.Message, _hostSessionPayloadFactory.BuildFailurePayload(coordination, toolName));
        }

        var forwarded = await _editorProxy.ForwardToolCallAsync(coordination.Session, toolName, forwardedArguments, cancellationToken);
        var centralHostSession = _hostSessionPayloadFactory.Build(coordination, forwarded.Endpoint, toolName);
        if (forwarded.Success)
        {
            return CentralToolCallResponse.Success(
                _hostSessionPayloadFactory.AttachToResult(forwarded.ToolResult ?? new { success = true }, centralHostSession));
        }

        return CentralToolCallResponse.Error(
            "Forwarded editor tool failed.",
            _hostSessionPayloadFactory.AttachToResult(
                forwarded.ToolResult ?? new
                {
                    error = "editor_tool_failed",
                    toolName,
                    project = coordination.Project,
                    editorSession = coordination.Session,
                    launch = coordination.Launch,
                },
                centralHostSession));
    }

}
