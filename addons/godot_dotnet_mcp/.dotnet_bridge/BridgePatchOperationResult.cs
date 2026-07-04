namespace GodotDotnetMcp.DotnetBridge;

internal sealed record BridgePatchOperationResult(
    string Kind,
    string Target,
    int MatchCount,
    int AppliedCount,
    string? Note);
