namespace GodotDotnetMcp.DotnetBridge;

internal sealed record SemanticMemberPatch(
    string TypeName,
    string MemberName,
    IReadOnlyList<string> Modifiers,
    string? ReturnType,
    IReadOnlyList<string> Parameters,
    string? Body,
    string? FieldType,
    string? Initializer,
    string? SignatureHint);

internal sealed record PatchOperationResult(
    string Kind,
    string Target,
    int MatchCount,
    int AppliedCount,
    string? Note);
