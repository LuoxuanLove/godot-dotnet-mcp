namespace GodotDotnetMcp.DotnetBridge;

internal sealed record CsDiagnosticsResult(
    string Path,
    string? ProjectPath,
    string Source,
    int ExitCode,
    IReadOnlyList<DiagnosticSummary> Errors,
    IReadOnlyList<DiagnosticSummary> Warnings,
    IReadOnlyDictionary<string, int> Summary,
    string StdOut,
    string StdErr);
