namespace GodotDotnetMcp.Companion.StaticAnalysis;

public sealed record ResourceReferenceGraph(
    IReadOnlyList<ResourceFileGraphItem> Files,
    IReadOnlyList<ResourceExternalResourceGraphItem> ExternalResources,
    IReadOnlyList<ResourceSubResourceGraphItem> SubResources,
    IReadOnlyList<ResourceReferenceUsageGraphItem> ReferenceUsages,
    IReadOnlyList<ResourceGraphDiagnostic> Diagnostics)
{
    public bool HasResources => Files.Count > 0;

    public bool HasDiagnostics => Diagnostics.Count > 0;
}

public sealed record ResourceFileGraphItem(
    string ResourcePath,
    string FilePath,
    ResourceFileKind Kind,
    bool SupportedTextFormat);

public enum ResourceFileKind
{
    Scene,
    TextResource,
    BinaryResource,
}

public sealed record ResourceExternalResourceGraphItem(
    string SourceResourcePath,
    int Line,
    string Id,
    string? Type,
    string? Path,
    string? Uid,
    string? ResolvedFilePath,
    bool? IsInsideProjectRoot,
    bool Exists);

public sealed record ResourceSubResourceGraphItem(
    string SourceResourcePath,
    int Line,
    string Id,
    string? Type);

public sealed record ResourceReferenceUsageGraphItem(
    string SourceResourcePath,
    int Line,
    ResourceReferenceUsageKind Kind,
    string Reference,
    string? ResolvedResourcePath,
    string? ResolvedFilePath,
    bool? IsInsideProjectRoot,
    bool Exists);

public enum ResourceReferenceUsageKind
{
    ExtResource,
    SubResource,
    Preload,
    Load,
    Uid,
}

public sealed record ResourceGraphDiagnostic(
    string ResourcePath,
    int? Line,
    ResourceGraphDiagnosticSeverity Severity,
    string Code,
    string Message);

public enum ResourceGraphDiagnosticSeverity
{
    Info,
    Warning,
    Error,
}
