using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Xml;
using System.Xml.Linq;

namespace GodotDotnetMcp.HostShared;

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

internal sealed record PatchOperationResult(
    string Kind,
    string Target,
    int MatchCount,
    int AppliedCount,
    string? Note);
