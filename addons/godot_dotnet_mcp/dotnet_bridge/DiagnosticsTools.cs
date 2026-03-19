using System.Globalization;
using System.Text.Json;
using System.Text.RegularExpressions;

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

internal static class CsDiagnosticsTool
{
    private static readonly Regex DiagnosticLineRegex = new(
        @"^(?<file>.+?)\((?<line>\d+),(?<column>\d+)\):\s+(?<severity>error|warning)\s+(?<code>[A-Z]+\d+):\s+(?<message>.+)$",
        RegexOptions.Compiled | RegexOptions.Multiline | RegexOptions.CultureInvariant);

    public static async Task<BridgeToolCallResponse> ExecuteAsync(JsonElement arguments, CancellationToken cancellationToken)
    {
        try
        {
            var path = WorkspacePathResolver.ResolveExistingPath(BridgeArgumentReader.GetRequiredString(arguments, "path"));
            var explicitProject = BridgeArgumentReader.TryGetString(arguments, "projectPath", out var projectPathValue)
                ? WorkspacePathResolver.ResolveExistingPath(projectPathValue!)
                : null;

            var projectPath = explicitProject ?? WorkspacePathResolver.FindNearestProjectFile(path);
            if (projectPath is null)
            {
                return BridgeToolCallResponse.Success(CSharpSyntaxFallbackDiagnostics.Analyze(path));
            }

            var buildResult = await DotnetCliRunner.RunAsync(projectPath, "build", "Debug", null, "minimal", cancellationToken);
            var diagnostics = ParseDiagnostics(buildResult.StdOut, buildResult.StdErr);
            var errors = diagnostics.Where(d => d.Severity.Equals("error", StringComparison.OrdinalIgnoreCase)).ToArray();
            var warnings = diagnostics.Where(d => d.Severity.Equals("warning", StringComparison.OrdinalIgnoreCase)).ToArray();

            var result = new CsDiagnosticsResult(
                Path: path,
                ProjectPath: projectPath,
                Source: "dotnet build",
                ExitCode: buildResult.ExitCode,
                Errors: errors,
                Warnings: warnings,
                Summary: new Dictionary<string, int>
                {
                    ["errorCount"] = errors.Length,
                    ["warningCount"] = warnings.Length,
                },
                StdOut: buildResult.StdOut,
                StdErr: buildResult.StdErr);

            return BridgeToolCallResponse.Success(result);
        }
        catch (BridgeToolException ex)
        {
            return BridgeToolCallResponse.Error(ex.Message, new { error = ex.Message });
        }
        catch (Exception ex)
        {
            return BridgeToolCallResponse.Error($"cs_diagnostics failed: {ex.Message}", new { error = ex.Message, exception = ex.GetType().Name });
        }
    }

    private static IReadOnlyList<DiagnosticSummary> ParseDiagnostics(string stdout, string stderr)
    {
        var diagnostics = new List<DiagnosticSummary>();
        ParseDiagnosticsInto(stdout, diagnostics);
        ParseDiagnosticsInto(stderr, diagnostics);
        return diagnostics;
    }

    private static void ParseDiagnosticsInto(string text, ICollection<DiagnosticSummary> diagnostics)
    {
        foreach (Match match in DiagnosticLineRegex.Matches(text))
        {
            diagnostics.Add(new DiagnosticSummary(
                Severity: match.Groups["severity"].Value,
                Code: match.Groups["code"].Value,
                Message: match.Groups["message"].Value.Trim(),
                FilePath: match.Groups["file"].Value.Trim(),
                Line: int.Parse(match.Groups["line"].Value, CultureInfo.InvariantCulture),
                Column: int.Parse(match.Groups["column"].Value, CultureInfo.InvariantCulture)));
        }
    }
}

internal static class CSharpSyntaxFallbackDiagnostics
{
    public static CsDiagnosticsResult Analyze(string path)
    {
        var text = File.ReadAllText(path);
        var issues = new List<DiagnosticSummary>();

        var openBraces = text.Count(c => c == '{');
        var closeBraces = text.Count(c => c == '}');
        if (openBraces != closeBraces)
        {
            issues.Add(new DiagnosticSummary(
                Severity: "error",
                Code: "BRACE001",
                Message: $"Brace count mismatch: {{={openBraces}, }}={closeBraces}.",
                FilePath: Path.GetFullPath(path),
                Line: null,
                Column: null));
        }

        var openParens = text.Count(c => c == '(');
        var closeParens = text.Count(c => c == ')');
        if (openParens != closeParens)
        {
            issues.Add(new DiagnosticSummary(
                Severity: "warning",
                Code: "PAREN001",
                Message: $"Parenthesis count mismatch: (={openParens}, )={closeParens}.",
                FilePath: Path.GetFullPath(path),
                Line: null,
                Column: null));
        }

        return new CsDiagnosticsResult(
            Path: Path.GetFullPath(path),
            ProjectPath: null,
            Source: "syntax fallback",
            ExitCode: issues.Any(issue => issue.Severity == "error") ? 1 : 0,
            Errors: issues.Where(issue => issue.Severity == "error").ToArray(),
            Warnings: issues.Where(issue => issue.Severity == "warning").ToArray(),
            Summary: DiagnosticSummaryExtensions.BuildSummary(issues),
            StdOut: string.Empty,
            StdErr: string.Empty);
    }
}
