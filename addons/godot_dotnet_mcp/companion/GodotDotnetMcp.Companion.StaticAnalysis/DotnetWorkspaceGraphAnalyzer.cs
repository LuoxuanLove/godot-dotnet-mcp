using System.Xml.Linq;

namespace GodotDotnetMcp.Companion.StaticAnalysis;

public sealed class DotnetWorkspaceGraphAnalyzer
{
    public DotnetWorkspaceGraph Analyze(string projectRoot, IEnumerable<string> projectFilePaths)
    {
        if (string.IsNullOrWhiteSpace(projectRoot))
        {
            throw new ArgumentException("Project root is required.", nameof(projectRoot));
        }

        var normalizedRoot = Path.GetFullPath(projectRoot);
        var orderedProjectFilePaths = projectFilePaths
            .Select(Path.GetFullPath)
            .Where(path => IsInside(normalizedRoot, path))
            .OrderBy(path => path, StringComparerForPlatform())
            .ToArray();

        var projects = new List<DotnetProjectGraph>();
        var diagnostics = new List<DotnetWorkspaceDiagnostic>();
        foreach (var path in orderedProjectFilePaths)
        {
            try
            {
                projects.Add(AnalyzeProject(normalizedRoot, path, diagnostics));
            }
            catch (Exception exception) when (IsRecoverableProjectReadException(exception))
            {
                diagnostics.Add(new DotnetWorkspaceDiagnostic(
                    ProjectFilePath: path,
                    Severity: DotnetWorkspaceDiagnosticSeverity.Error,
                    Code: "dotnet_workspace_project_unreadable",
                    Message: $"Unable to read .NET project file: {exception.Message}"));
            }
        }

        return new DotnetWorkspaceGraph(projects, diagnostics);
    }

    private static DotnetProjectGraph AnalyzeProject(
        string projectRoot,
        string projectFilePath,
        List<DotnetWorkspaceDiagnostic> diagnostics)
    {
        var document = XDocument.Load(projectFilePath, LoadOptions.PreserveWhitespace | LoadOptions.SetLineInfo);
        var root = document.Root ?? throw new InvalidDataException($"Project file has no root element: {projectFilePath}");
        var projectDirectory = Path.GetDirectoryName(projectFilePath) ?? projectRoot;

        var packageReferences = new List<PackageReferenceGraphItem>();
        foreach (var element in Descendants(root, "PackageReference"))
        {
            var include = RequiredAttribute(
                projectFilePath,
                diagnostics,
                element,
                "Include",
                "PackageReference",
                "dotnet_workspace_package_reference_missing_include");
            if (include is null)
            {
                continue;
            }

            packageReferences.Add(new PackageReferenceGraphItem(
                Include: include,
                Version: AttributeOrChildValue(element, "Version"),
                Condition: ConditionFor(element)));
        }

        var projectReferences = new List<ProjectReferenceGraphItem>();
        foreach (var element in Descendants(root, "ProjectReference"))
        {
            var include = RequiredAttribute(
                projectFilePath,
                diagnostics,
                element,
                "Include",
                "ProjectReference",
                "dotnet_workspace_project_reference_missing_include");
            if (include is null)
            {
                continue;
            }

            try
            {
                var resolvedPath = Path.GetFullPath(include, projectDirectory);
                projectReferences.Add(new ProjectReferenceGraphItem(
                    Include: include,
                    ResolvedPath: resolvedPath,
                    IsInsideProjectRoot: IsInside(projectRoot, resolvedPath),
                    Exists: File.Exists(resolvedPath),
                    Condition: ConditionFor(element)));
            }
            catch (Exception exception) when (IsRecoverableProjectReferenceException(exception))
            {
                diagnostics.Add(new DotnetWorkspaceDiagnostic(
                    ProjectFilePath: projectFilePath,
                    Severity: DotnetWorkspaceDiagnosticSeverity.Warning,
                    Code: "dotnet_workspace_project_reference_unresolved",
                    Message: $"Unable to resolve ProjectReference '{include}': {exception.Message}"));
            }
        }

        var compileItems = Descendants(root, "Compile")
            .Where(element => element.Attribute("Include") is not null || element.Attribute("Remove") is not null)
            .Select(element => new CompileItemGraphItem(
                Include: (string?)element.Attribute("Include") ?? string.Empty,
                Remove: (string?)element.Attribute("Remove"),
                Condition: ConditionFor(element)))
            .ToArray();

        var targetFrameworks = TargetFrameworks(root);
        var sdk = (string?)root.Attribute("Sdk");

        return new DotnetProjectGraph(
            ProjectFilePath: projectFilePath,
            Sdk: sdk,
            TargetFrameworks: targetFrameworks,
            PackageReferences: packageReferences,
            ProjectReferences: projectReferences,
            CompileItems: compileItems,
            IsGodotSdkStyleProject: IsGodotProject(sdk, packageReferences));
    }

    private static IReadOnlyList<string> TargetFrameworks(XElement root)
    {
        var targetFramework = ChildValue(root, "TargetFramework");
        var targetFrameworks = ChildValue(root, "TargetFrameworks");
        if (!string.IsNullOrWhiteSpace(targetFrameworks))
        {
            return targetFrameworks
                .Split(';', StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries)
                .ToArray();
        }

        return string.IsNullOrWhiteSpace(targetFramework)
            ? []
            : [targetFramework];
    }

    private static bool IsGodotProject(string? sdk, IReadOnlyList<PackageReferenceGraphItem> packageReferences)
    {
        if (!string.IsNullOrWhiteSpace(sdk) &&
            sdk.Contains("Godot", StringComparison.OrdinalIgnoreCase))
        {
            return true;
        }

        return packageReferences.Any(package =>
            package.Include.Contains("Godot", StringComparison.OrdinalIgnoreCase));
    }

    private static IEnumerable<XElement> Descendants(XElement root, string localName)
    {
        return root.Descendants().Where(element => element.Name.LocalName == localName);
    }

    private static string? RequiredAttribute(
        string projectFilePath,
        List<DotnetWorkspaceDiagnostic> diagnostics,
        XElement element,
        string name,
        string context,
        string code)
    {
        var value = (string?)element.Attribute(name);
        if (string.IsNullOrWhiteSpace(value))
        {
            diagnostics.Add(new DotnetWorkspaceDiagnostic(
                ProjectFilePath: projectFilePath,
                Severity: DotnetWorkspaceDiagnosticSeverity.Warning,
                Code: code,
                Message: $"{context} without '{name}' was ignored."));
            return null;
        }

        return value;
    }

    private static string? AttributeOrChildValue(XElement element, string name)
    {
        return (string?)element.Attribute(name) ??
            element.Elements().FirstOrDefault(child => child.Name.LocalName == name)?.Value;
    }

    private static string? ChildValue(XElement root, string name)
    {
        return root.Descendants().FirstOrDefault(element => element.Name.LocalName == name)?.Value;
    }

    private static string? ConditionFor(XElement element)
    {
        return (string?)element.Attribute("Condition") ??
            element.Ancestors().Select(ancestor => (string?)ancestor.Attribute("Condition")).FirstOrDefault(condition => !string.IsNullOrWhiteSpace(condition));
    }

    private static bool IsRecoverableProjectReadException(Exception exception)
    {
        return exception is UnauthorizedAccessException or IOException or InvalidDataException or System.Xml.XmlException;
    }

    private static bool IsRecoverableProjectReferenceException(Exception exception)
    {
        return exception is ArgumentException or NotSupportedException or PathTooLongException;
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
