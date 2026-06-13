using GodotDotnetMcp.Companion;

namespace GodotDotnetMcp.Companion.StaticAnalysis;

public sealed class ProjectInventoryAnalyzer
{
    private static readonly string[] PluginOwnedProjectDirectoryFragments =
    [
        Path.Combine("addons", "godot_dotnet_mcp", "companion"),
        Path.Combine("addons", "godot_dotnet_mcp", "dotnet_bridge"),
    ];

    public ProjectInventory Analyze(string projectRoot)
    {
        if (string.IsNullOrWhiteSpace(projectRoot))
        {
            throw new ArgumentException("Project root is required.", nameof(projectRoot));
        }

        var normalizedRoot = Path.GetFullPath(projectRoot);
        var projectFilePath = Path.Combine(normalizedRoot, "project.godot");
        var isGodotProject = File.Exists(projectFilePath);
        var csprojFiles = isGodotProject
            ? EnumerateProjectFiles(normalizedRoot)
                .OrderBy(path => path, StringComparerForPlatform())
                .ToArray()
            : [];
        var pluginDirectory = Path.Combine(normalizedRoot, "addons", "godot_dotnet_mcp");
        var hasPluginDirectory = Directory.Exists(pluginDirectory);
        var dotnetWorkspace = new DotnetWorkspaceGraphAnalyzer().Analyze(normalizedRoot, csprojFiles);
        var resourceReferences = isGodotProject
            ? new ResourceReferenceGraphAnalyzer().Analyze(normalizedRoot)
            : EmptyResourceGraph();

        var descriptor = TryCreateDescriptor(normalizedRoot, isGodotProject);
        var projectScopes = isGodotProject
            ? BuildProjectScopes(normalizedRoot, csprojFiles)
            : [];
        var defaultProjectScope = SelectDefaultProjectScope(projectScopes);
        var capabilities = BuildCapabilities(isGodotProject, dotnetWorkspace);

        return new ProjectInventory(
            ProjectRoot: normalizedRoot,
            ProjectId: descriptor?.ProjectId,
            IsGodotProject: isGodotProject,
            ProjectFilePath: projectFilePath,
            CSharpProjectFiles: csprojFiles,
            CSharpProjectScopes: projectScopes,
            DefaultCSharpProjectScope: defaultProjectScope,
            ProjectScopeSelection: BuildProjectScopeSelection(isGodotProject, projectScopes, defaultProjectScope),
            DotnetWorkspace: dotnetWorkspace,
            ResourceReferences: resourceReferences,
            HasPluginDirectory: hasPluginDirectory,
            Mode: CompanionMode.StaticHeadless,
            Capabilities: capabilities);
    }

    private static ResourceReferenceGraph EmptyResourceGraph()
    {
        return new ResourceReferenceGraph([], [], [], [], []);
    }

    private static ProjectDescriptor? TryCreateDescriptor(string projectRoot, bool isGodotProject)
    {
        if (!isGodotProject)
        {
            return null;
        }

        return ProjectDescriptor.FromRoot(projectRoot);
    }

    private static IReadOnlyList<CSharpProjectScope> BuildProjectScopes(string projectRoot, IReadOnlyList<string> projectFiles)
    {
        return projectFiles
            .Select(projectFile =>
            {
                var descriptor = ProjectDescriptor.FromRoot(projectRoot, projectFile);
                return new CSharpProjectScope(projectFile, descriptor.ProjectId);
            })
            .ToArray();
    }

    private static CSharpProjectScope? SelectDefaultProjectScope(IReadOnlyList<CSharpProjectScope> projectScopes)
    {
        return projectScopes.Count == 1 ? projectScopes[0] : null;
    }

    private static ProjectScopeSelection BuildProjectScopeSelection(
        bool isGodotProject,
        IReadOnlyList<CSharpProjectScope> projectScopes,
        CSharpProjectScope? defaultProjectScope)
    {
        if (!isGodotProject)
        {
            return new ProjectScopeSelection(
                RequiresExplicitSelection: false,
                CandidateCount: 0,
                Reason: "Requires a project.godot file before C# project scope selection is available.");
        }

        if (projectScopes.Count == 0)
        {
            return new ProjectScopeSelection(
                RequiresExplicitSelection: false,
                CandidateCount: 0,
                Reason: "No .csproj files were discovered inside the project root.");
        }

        if (defaultProjectScope is not null)
        {
            return new ProjectScopeSelection(
                RequiresExplicitSelection: false,
                CandidateCount: projectScopes.Count,
                Reason: "Exactly one .csproj scope was discovered and selected as the default.");
        }

        return new ProjectScopeSelection(
            RequiresExplicitSelection: true,
            CandidateCount: projectScopes.Count,
            Reason: "Multiple .csproj scopes were discovered; clients must select an explicit project_id before starting a scoped session.");
    }

    private static IReadOnlyList<ProjectCapabilityStatus> BuildCapabilities(bool isGodotProject, DotnetWorkspaceGraph dotnetWorkspace)
    {
        var dotnetWorkspaceReason = isGodotProject
            ? DotnetWorkspaceUnavailableReason(dotnetWorkspace)
            : "Requires a project.godot file.";

        return
        [
            StaticCapability(
                CompanionCapability.StaticProjectAnalysis,
                isGodotProject,
                "Requires a project.godot file."),
            StaticCapability(
                CompanionCapability.DotnetWorkspaceAnalysis,
                isGodotProject && dotnetWorkspace.HasProjects,
                dotnetWorkspace.HasProjects ? "Available from parsed .csproj files." : dotnetWorkspaceReason),
            StaticCapability(
                CompanionCapability.ResourceGraphAnalysis,
                isGodotProject,
                "Requires a project.godot file."),
            LiveCapability(CompanionCapability.EditorSelection),
            LiveCapability(CompanionCapability.InspectorState),
            LiveCapability(CompanionCapability.DockState),
            LiveCapability(CompanionCapability.EditorScreenshot),
            LiveCapability(CompanionCapability.RuntimeValidation),
        ];
    }

    private static string DotnetWorkspaceUnavailableReason(DotnetWorkspaceGraph dotnetWorkspace)
    {
        return dotnetWorkspace.HasDiagnostics
            ? "No .csproj file could be parsed successfully; inspect .NET workspace diagnostics."
            : "Requires at least one .csproj file inside the project root.";
    }

    private static ProjectCapabilityStatus StaticCapability(
        CompanionCapability capability,
        bool available,
        string unavailableReason)
    {
        return new ProjectCapabilityStatus(
            Capability: capability,
            Mode: CompanionMode.StaticHeadless,
            Available: available,
            Reason: available ? "Available from static/headless project analysis." : unavailableReason);
    }

    private static ProjectCapabilityStatus LiveCapability(CompanionCapability capability)
    {
        return new ProjectCapabilityStatus(
            Capability: capability,
            Mode: CompanionMode.EditorLive,
            Available: false,
            Reason: "Requires an online Godot editor bridge and explicit editor-live upgrade.");
    }

    private static IEnumerable<string> EnumerateProjectFiles(string projectRoot)
    {
        var stack = new Stack<DirectoryInfo>();
        stack.Push(new DirectoryInfo(projectRoot));

        while (stack.Count > 0)
        {
            var directory = stack.Pop();
            foreach (var file in SafeEnumerateFiles(directory))
            {
                if ((file.Attributes & FileAttributes.ReparsePoint) != 0)
                {
                    continue;
                }

                var normalizedPath = Path.GetFullPath(file.FullName);
                if (IsInside(projectRoot, normalizedPath))
                {
                    yield return normalizedPath;
                }
            }

            foreach (var childDirectory in SafeEnumerateDirectories(directory))
            {
                if (ShouldEnterDirectory(projectRoot, childDirectory))
                {
                    stack.Push(childDirectory);
                }
            }
        }
    }

    private static IEnumerable<FileInfo> SafeEnumerateFiles(DirectoryInfo directory)
    {
        try
        {
            return directory.EnumerateFiles("*.csproj", SearchOption.TopDirectoryOnly).ToArray();
        }
        catch (UnauthorizedAccessException)
        {
            return [];
        }
        catch (IOException)
        {
            return [];
        }
    }

    private static IEnumerable<DirectoryInfo> SafeEnumerateDirectories(DirectoryInfo directory)
    {
        try
        {
            return directory.EnumerateDirectories("*", SearchOption.TopDirectoryOnly).ToArray();
        }
        catch (UnauthorizedAccessException)
        {
            return [];
        }
        catch (IOException)
        {
            return [];
        }
    }

    private static bool ShouldEnterDirectory(string projectRoot, DirectoryInfo directory)
    {
        var attributes = directory.Attributes;
        if ((attributes & FileAttributes.Hidden) != 0 ||
            (attributes & FileAttributes.System) != 0 ||
            (attributes & FileAttributes.ReparsePoint) != 0)
        {
            return false;
        }

        if (directory.Name.StartsWith(".", StringComparison.Ordinal))
        {
            return false;
        }

        var normalizedDirectory = Path.GetFullPath(directory.FullName);
        return IsInside(projectRoot, normalizedDirectory) &&
            !IsPluginOwnedProjectDirectory(projectRoot, normalizedDirectory);
    }

    private static bool IsPluginOwnedProjectDirectory(string projectRoot, string directoryPath)
    {
        foreach (var relativeDirectory in PluginOwnedProjectDirectoryFragments)
        {
            var pluginOwnedDirectory = Path.Combine(projectRoot, relativeDirectory);
            if (IsSameOrInside(pluginOwnedDirectory, directoryPath))
            {
                return true;
            }
        }

        return false;
    }

    private static bool IsInside(string root, string path)
    {
        var normalizedRoot = Path.TrimEndingDirectorySeparator(Path.GetFullPath(root)) + Path.DirectorySeparatorChar;
        var normalizedPath = Path.GetFullPath(path);
        return normalizedPath.StartsWith(normalizedRoot, StringComparisonForPlatform());
    }

    private static bool IsSameOrInside(string root, string path)
    {
        var normalizedRoot = Path.TrimEndingDirectorySeparator(Path.GetFullPath(root));
        var normalizedPath = Path.TrimEndingDirectorySeparator(Path.GetFullPath(path));
        var comparison = StringComparisonForPlatform();
        return string.Equals(normalizedRoot, normalizedPath, comparison) ||
            normalizedPath.StartsWith(normalizedRoot + Path.DirectorySeparatorChar, comparison);
    }

    private static StringComparer StringComparerForPlatform()
    {
        return OperatingSystem.IsWindows() ? StringComparer.OrdinalIgnoreCase : StringComparer.Ordinal;
    }

    private static StringComparison StringComparisonForPlatform()
    {
        return OperatingSystem.IsWindows() ? StringComparison.OrdinalIgnoreCase : StringComparison.Ordinal;
    }
}
