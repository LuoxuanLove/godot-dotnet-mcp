namespace GodotDotnetMcp.DotnetBridge;

internal sealed record CsprojWriteResult(
    string Path,
    bool DryRun,
    bool Written,
    IReadOnlyList<string> Changes,
    IReadOnlyList<string> Warnings,
    string Preview,
    string ContentHash,
    string? TargetFramework,
    IReadOnlyList<string> TargetFrameworks,
    IReadOnlyList<CsprojReferenceInfo> PackageReferences,
    IReadOnlyList<CsprojReferenceInfo> ProjectReferences);

internal sealed record CsFilePatchResult(
    string Path,
    bool DryRun,
    bool Written,
    IReadOnlyList<PatchOperationResult> Operations,
    IReadOnlyList<string> Warnings,
    string Preview,
    string ContentHash,
    int OriginalLength,
    int NewLength);
