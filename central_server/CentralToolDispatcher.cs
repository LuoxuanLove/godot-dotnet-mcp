using System.Text.Json;
using GodotDotnetMcp.HostShared;

namespace GodotDotnetMcp.CentralServer;

internal sealed class CentralToolDispatcher
{
    private readonly CentralConfigurationService _configuration;
    private readonly EditorProxyService _editorProxy;
    private readonly EditorProcessService _editorProcesses;
    private readonly EditorSessionService _editorSessions;
    private readonly GodotInstallationService _godotInstallations;
    private readonly GodotProjectManagerProvider _godotProjectManager;
    private readonly ProjectRegistryService _registry;
    private readonly SessionState _sessionState;

    public CentralToolDispatcher(
        CentralConfigurationService configuration,
        EditorProxyService editorProxy,
        EditorProcessService editorProcesses,
        EditorSessionService editorSessions,
        GodotInstallationService godotInstallations,
        GodotProjectManagerProvider godotProjectManager,
        ProjectRegistryService registry,
        SessionState sessionState)
    {
        _configuration = configuration;
        _editorProxy = editorProxy;
        _editorProcesses = editorProcesses;
        _editorSessions = editorSessions;
        _godotInstallations = godotInstallations;
        _godotProjectManager = godotProjectManager;
        _registry = registry;
        _sessionState = sessionState;
    }

    public async Task<CentralToolCallResponse> ExecuteAsync(string toolName, JsonElement arguments, CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();

        try
        {
            return toolName switch
            {
                "workspace_project_list" => ListProjects(),
                "workspace_project_register" => RegisterProject(arguments),
                "workspace_project_remove" => RemoveProject(arguments),
                "workspace_project_select" => SelectProject(arguments),
                "workspace_project_status" => GetStatus(arguments),
                "workspace_project_rescan" => RescanProjects(arguments),
                "workspace_editor_session_list" => ListEditorSessions(),
                "workspace_editor_proxy_call" => await ProxyEditorCallAsync(arguments, cancellationToken),
                "workspace_project_set_godot_path" => SetProjectGodotPath(arguments),
                "workspace_project_open_editor" => OpenProjectEditor(arguments),
                "workspace_godot_installation_list" => ListGodotInstallations(),
                "workspace_godot_set_default_executable" => SetDefaultGodotExecutable(arguments),
                "workspace_godot_manager_list_projects" => ListGodotManagerProjects(),
                "workspace_godot_manager_get_status" => GetGodotManagerStatus(),
                "workspace_godot_manager_import_projects" => ImportGodotManagerProjects(arguments),
                _ => await ExecuteDotnetToolAsync(toolName, arguments, cancellationToken),
            };
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

    private CentralToolCallResponse ListProjects()
    {
        var projects = _registry.ListProjects();
        return CentralToolCallResponse.Success(new
        {
            activeProjectId = _sessionState.ActiveProjectId,
            projects,
            count = projects.Count,
        });
    }

    private CentralToolCallResponse RegisterProject(JsonElement arguments)
    {
        var projectPath = CentralArgumentReader.GetRequiredString(arguments, "path");
        var source = CentralArgumentReader.GetOptionalString(arguments, "source") ?? "manual";
        var project = _registry.RegisterProject(projectPath, source);
        return CentralToolCallResponse.Success(new
        {
            registered = true,
            project,
            activeProjectId = _sessionState.ActiveProjectId,
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

        if (string.Equals(_sessionState.ActiveProjectId, removedProject.ProjectId, StringComparison.OrdinalIgnoreCase))
        {
            _sessionState.ActiveProjectId = string.Empty;
        }

        return CentralToolCallResponse.Success(new
        {
            removed = true,
            project = removedProject,
            activeProjectId = _sessionState.ActiveProjectId,
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

        _sessionState.ActiveProjectId = project.ProjectId;
        return CentralToolCallResponse.Success(new
        {
            selected = true,
            activeProjectId = _sessionState.ActiveProjectId,
            project,
        });
    }

    private CentralToolCallResponse GetStatus(JsonElement arguments)
    {
        var projectId = CentralArgumentReader.GetOptionalString(arguments, "projectId");
        var path = CentralArgumentReader.GetOptionalString(arguments, "path");
        var project = _registry.ResolveProject(projectId, path)
                      ?? _registry.ResolveProject(_sessionState.ActiveProjectId, null);
        var status = _registry.BuildStatus(_sessionState.ActiveProjectId);
        var editorStatus = project is null
            ? null
            : _editorProcesses.GetStatus(project.ProjectId);
        var editorSessionStatus = project is null
            ? null
            : _editorSessions.GetStatus(project.ProjectId);

        return CentralToolCallResponse.Success(new
        {
            status,
            configuration = _configuration.BuildStatus(),
            project,
            editor = editorStatus,
            editorSession = editorSessionStatus,
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
        return CentralToolCallResponse.Success(new
        {
            importDiscovered,
            result.Roots,
            result.DiscoveredProjectRoots,
            result.ImportedProjects,
            result.DuplicateProjectRoots,
            activeProjectId = _sessionState.ActiveProjectId,
        });
    }

    private CentralToolCallResponse ListEditorSessions()
    {
        var sessions = _editorSessions.ListSessions();
        return CentralToolCallResponse.Success(new
        {
            count = sessions.Count,
            sessions,
        });
    }

    private async Task<CentralToolCallResponse> ProxyEditorCallAsync(JsonElement arguments, CancellationToken cancellationToken)
    {
        var requestedToolName = CentralArgumentReader.GetRequiredString(arguments, "toolName");
        var projectId = CentralArgumentReader.GetOptionalString(arguments, "projectId");
        var path = CentralArgumentReader.GetOptionalString(arguments, "path");
        var forwardedArguments = CentralArgumentReader.GetObjectElementOrEmpty(arguments, "arguments");
        var project = _registry.ResolveProject(projectId, path)
                      ?? _registry.ResolveProject(_sessionState.ActiveProjectId, null);
        if (project is null)
        {
            throw new CentralToolException("Registered project not found or no active project is selected.");
        }

        var session = _editorSessions.GetStatus(project.ProjectId);
        if (!session.Attached)
        {
            return CentralToolCallResponse.Error(
                "Editor-attached tool requires an active editor session.",
                new
                {
                    error = "editor_required",
                    requiredState = "editor_attached",
                    projectId = project.ProjectId,
                    projectName = project.ProjectName,
                    toolName = requestedToolName,
                    editorSession = session,
                });
        }

        if (!string.Equals(session.TransportMode, "http", StringComparison.OrdinalIgnoreCase)
            && !string.Equals(session.TransportMode, "both", StringComparison.OrdinalIgnoreCase))
        {
            return CentralToolCallResponse.Error(
                "Editor-attached tool requires an HTTP-capable editor session.",
                new
                {
                    error = "editor_transport_unavailable",
                    requiredTransport = "http",
                    actualTransport = session.TransportMode,
                    projectId = project.ProjectId,
                    projectName = project.ProjectName,
                    toolName = requestedToolName,
                    editorSession = session,
                });
        }

        if (!session.ServerRunning || string.IsNullOrWhiteSpace(session.ServerHost) || session.ServerPort is null or <= 0)
        {
            return CentralToolCallResponse.Error(
                "Editor session is attached but its HTTP MCP endpoint is not available.",
                new
                {
                    error = "editor_endpoint_unavailable",
                    projectId = project.ProjectId,
                    projectName = project.ProjectName,
                    toolName = requestedToolName,
                    editorSession = session,
                });
        }

        var forwarded = await _editorProxy.ForwardToolCallAsync(session, requestedToolName, forwardedArguments, cancellationToken);
        var payload = new
        {
            forwarded = true,
            status = forwarded.Success ? "forwarded" : "forwarded_error",
            endpoint = forwarded.Endpoint,
            project,
            editorSession = session,
            toolName = requestedToolName,
            arguments = JsonSerializer.Deserialize<object>(forwardedArguments.GetRawText(), CentralServerSerialization.JsonOptions),
            forwardedResult = forwarded.ToolResult,
            message = forwarded.Message,
        };

        return forwarded.Success
            ? CentralToolCallResponse.Success(payload)
            : CentralToolCallResponse.Error("Forwarded editor tool failed.", payload);
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

    private CentralToolCallResponse OpenProjectEditor(JsonElement arguments)
    {
        var projectId = CentralArgumentReader.GetOptionalString(arguments, "projectId");
        var path = CentralArgumentReader.GetOptionalString(arguments, "path");
        var explicitExecutablePath = CentralArgumentReader.GetOptionalString(arguments, "executablePath") ?? string.Empty;
        var project = _registry.ResolveProject(projectId, path)
                      ?? _registry.ResolveProject(_sessionState.ActiveProjectId, null);
        if (project is null)
        {
            throw new CentralToolException("Registered project not found or no active project is selected.");
        }

        var resolution = _godotInstallations.ResolveExecutable(project, explicitExecutablePath, _configuration);
        var launch = _editorProcesses.OpenProject(project, resolution.ExecutablePath, resolution.Source);
        return CentralToolCallResponse.Success(new
        {
            launch,
            project,
        });
    }

    private CentralToolCallResponse ListGodotInstallations()
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

    private CentralToolCallResponse ListGodotManagerProjects()
    {
        var candidates = _godotProjectManager.ListProjects(_registry.GetRegisteredProjectRoots());
        return CentralToolCallResponse.Success(new
        {
            count = candidates.Count,
            candidates,
        });
    }

    private CentralToolCallResponse GetGodotManagerStatus()
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
}
