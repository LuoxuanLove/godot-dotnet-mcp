namespace GodotDotnetMcp.Companion.StaticAnalysis;

public sealed record DotnetWorkspaceGraph(
    IReadOnlyList<DotnetProjectGraph> Projects,
    IReadOnlyList<DotnetWorkspaceDiagnostic> Diagnostics)
{
    public bool HasProjects => Projects.Count > 0;

    public bool HasDiagnostics => Diagnostics.Count > 0;
}

public sealed record DotnetProjectGraph(
    string ProjectFilePath,
    string? Sdk,
    IReadOnlyList<string> TargetFrameworks,
    IReadOnlyList<PackageReferenceGraphItem> PackageReferences,
    IReadOnlyList<ProjectReferenceGraphItem> ProjectReferences,
    IReadOnlyList<CompileItemGraphItem> CompileItems,
    bool IsGodotSdkStyleProject);

public sealed record PackageReferenceGraphItem(
    string Include,
    string? Version,
    string? Condition);

public sealed record ProjectReferenceGraphItem(
    string Include,
    string ResolvedPath,
    bool IsInsideProjectRoot,
    bool Exists,
    string? Condition);

public sealed record CompileItemGraphItem(
    string Include,
    string? Remove,
    string? Condition);

public sealed record DotnetWorkspaceDiagnostic(
    string ProjectFilePath,
    DotnetWorkspaceDiagnosticSeverity Severity,
    string Code,
    string Message);

public enum DotnetWorkspaceDiagnosticSeverity
{
    Warning,
    Error,
}
