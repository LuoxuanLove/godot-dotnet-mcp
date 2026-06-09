using GodotDotnetMcp.Companion;

namespace GodotDotnetMcp.Companion.StaticAnalysis;

public sealed class ProjectInventoryAnalyzer
{
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

        var descriptor = TryCreateDescriptor(normalizedRoot, isGodotProject, csprojFiles.FirstOrDefault());
        var capabilities = BuildCapabilities(isGodotProject, dotnetWorkspace);

        return new ProjectInventory(
            ProjectRoot: normalizedRoot,
            ProjectId: descriptor?.ProjectId,
            IsGodotProject: isGodotProject,
            ProjectFilePath: projectFilePath,
            CSharpProjectFiles: csprojFiles,
            DotnetWorkspace: dotnetWorkspace,
            HasPluginDirectory: hasPluginDirectory,
            Mode: CompanionMode.StaticHeadless,
            Capabilities: capabilities);
    }

    private static ProjectDescriptor? TryCreateDescriptor(string projectRoot, bool isGodotProject, string? firstProjectFile)
    {
        if (!isGodotProject)
        {
            return null;
        }

        return ProjectDescriptor.FromRoot(projectRoot, firstProjectFile);
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
        return IsInside(projectRoot, normalizedDirectory);
    }

    private static bool IsInside(string root, string path)
    {
        var normalizedRoot = Path.TrimEndingDirectorySeparator(Path.GetFullPath(root)) + Path.DirectorySeparatorChar;
        var normalizedPath = Path.GetFullPath(path);
        return normalizedPath.StartsWith(normalizedRoot, StringComparisonForPlatform());
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
