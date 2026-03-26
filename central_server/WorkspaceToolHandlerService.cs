using System.Text.Json;

namespace GodotDotnetMcp.CentralServer;

internal sealed class WorkspaceToolHandlerService
{
    private readonly CentralConfigurationService _configuration;
    private readonly EditorSessionService _editorSessions;
    private readonly GodotInstallationService _godotInstallations;
    private readonly GodotProjectManagerProvider _godotProjectManager;
    private readonly ProjectRegistryService _registry;
    private readonly CentralWorkspaceState _workspaceState;

    public WorkspaceToolHandlerService(
        CentralConfigurationService configuration,
        EditorSessionService editorSessions,
        GodotInstallationService godotInstallations,
        GodotProjectManagerProvider godotProjectManager,
        ProjectRegistryService registry,
        CentralWorkspaceState workspaceState)
    {
        _configuration = configuration;
        _editorSessions = editorSessions;
        _godotInstallations = godotInstallations;
        _godotProjectManager = godotProjectManager;
        _registry = registry;
        _workspaceState = workspaceState;
    }

    public void RegisterHandlers(CentralToolHandlerRegistry handlers)
    {
        handlers
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
}
