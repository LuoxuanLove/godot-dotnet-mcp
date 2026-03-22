using System.Text.Json;
using System.Text.RegularExpressions;

namespace GodotDotnetMcp.HostShared;

internal sealed record SolutionProjectReferenceInfo(string Include, string? ResolvedPath, bool Exists);

internal sealed record SolutionProjectSummary(
    string Name,
    string RelativePath,
    string FullPath,
    bool Exists,
    IReadOnlyList<string> TargetFrameworks,
    IReadOnlyList<CsprojReferenceInfo> PackageReferences,
    IReadOnlyList<SolutionProjectReferenceInfo> ProjectReferences);

internal sealed record SolutionReferenceIssue(string ProjectPath, string ReferencePath, string? ResolvedPath, string Reason);

internal sealed record SolutionAnalyzeResult(
    string SolutionPath,
    IReadOnlyList<SolutionProjectSummary> Projects,
    IReadOnlyList<object> DependencyGraph,
    IReadOnlyList<string> MissingProjects,
    IReadOnlyList<SolutionReferenceIssue> MissingReferences,
    IReadOnlyDictionary<string, int> Summary);

internal static class SolutionAnalyzeTool
{
    public static BridgeToolCallResponse Execute(JsonElement arguments)
    {
        try
        {
            var path = WorkspacePathResolver.ResolveSolutionFile(BridgeArgumentReader.GetRequiredString(arguments, "path"));
            var result = SolutionAnalyzer.Analyze(path);
            return BridgeToolCallResponse.Success(result);
        }
        catch (BridgeToolException ex)
        {
            return BridgeToolCallResponse.Error(ex.Message, new { error = ex.Message });
        }
        catch (Exception ex)
        {
            return BridgeToolCallResponse.Error($"solution_analyze failed: {ex.Message}", new { error = ex.Message, exception = ex.GetType().Name });
        }
    }
}

internal static class SolutionAnalyzer
{
    private static readonly Regex SolutionProjectRegex = new(
        "^Project\\(\"(?<typeGuid>[^\"]+)\"\\) = \"(?<name>[^\"]+)\", \"(?<path>[^\"]+)\", \"(?<guid>[^\"]+)\"$",
        RegexOptions.Compiled | RegexOptions.CultureInvariant);

    public static SolutionAnalyzeResult Analyze(string solutionPath)
    {
        var solutionDirectory = Path.GetDirectoryName(solutionPath) ?? Environment.CurrentDirectory;
        var solutionLines = File.ReadAllLines(solutionPath);
        var solutionProjects = new List<(string Name, string RelativePath, string FullPath, bool Exists)>();

        foreach (var line in solutionLines)
        {
            var match = SolutionProjectRegex.Match(line);
            if (!match.Success)
            {
                continue;
            }

            var relativePath = match.Groups["path"].Value.Replace('\\', Path.DirectorySeparatorChar);
            var fullPath = Path.GetFullPath(Path.Combine(solutionDirectory, relativePath));
            solutionProjects.Add((match.Groups["name"].Value, relativePath, fullPath, File.Exists(fullPath)));
        }

        var projectSummaries = new List<SolutionProjectSummary>();
        var dependencyGraph = new List<object>();
        var missingProjects = new List<string>();
        var missingReferences = new List<SolutionReferenceIssue>();

        foreach (var project in solutionProjects)
        {
            if (!project.Exists)
            {
                missingProjects.Add(project.FullPath);
                continue;
            }

            var model = CsprojReader.Read(project.FullPath);
            var resolvedReferences = new List<SolutionProjectReferenceInfo>();

            foreach (var reference in model.ProjectReferences)
            {
                var resolvedPath = Path.GetFullPath(Path.Combine(Path.GetDirectoryName(project.FullPath) ?? solutionDirectory, reference.Include.Replace('\\', Path.DirectorySeparatorChar)));
                var exists = File.Exists(resolvedPath);
                resolvedReferences.Add(new SolutionProjectReferenceInfo(reference.Include, exists ? resolvedPath : null, exists));

                if (!exists)
                {
                    missingReferences.Add(new SolutionReferenceIssue(project.FullPath, reference.Include, resolvedPath, "Project reference target does not exist."));
                }
            }

            projectSummaries.Add(new SolutionProjectSummary(
                Name: project.Name,
                RelativePath: project.RelativePath,
                FullPath: project.FullPath,
                Exists: true,
                TargetFrameworks: model.TargetFrameworks,
                PackageReferences: model.PackageReferences,
                ProjectReferences: resolvedReferences));

            dependencyGraph.Add(new
            {
                project = project.FullPath,
                references = resolvedReferences.Where(reference => reference.Exists).Select(reference => reference.ResolvedPath).ToArray(),
            });
        }

        return new SolutionAnalyzeResult(
            SolutionPath: Path.GetFullPath(solutionPath),
            Projects: projectSummaries,
            DependencyGraph: dependencyGraph,
            MissingProjects: missingProjects,
            MissingReferences: missingReferences,
            Summary: new Dictionary<string, int>
            {
                ["solutionProjectCount"] = solutionProjects.Count,
                ["resolvedProjectCount"] = projectSummaries.Count,
                ["missingProjectCount"] = missingProjects.Count,
                ["missingReferenceCount"] = missingReferences.Count,
            });
    }
}
