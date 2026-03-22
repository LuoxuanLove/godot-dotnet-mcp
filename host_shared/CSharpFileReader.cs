using System.Text.RegularExpressions;

namespace GodotDotnetMcp.HostShared;

internal sealed record CSharpTypeSummary(string Kind, string Name, IReadOnlyList<string> Modifiers, int Line, int Column);

internal sealed record CSharpMethodSummary(
    string Name,
    string ReturnType,
    string Parameters,
    IReadOnlyList<string> Modifiers,
    int Line,
    int Column,
    string? ContainingType);

internal sealed record CSharpFileReadModel(
    string Path,
    string? Namespace,
    IReadOnlyList<string> Usings,
    IReadOnlyList<CSharpTypeSummary> Types,
    IReadOnlyList<CSharpMethodSummary> Methods);

internal static class CSharpFileReader
{
    private static readonly Regex NamespaceRegex = new(@"^\s*namespace\s+(?<name>[A-Za-z_][\w\.]*)\s*(?:;|\{)?\s*$", RegexOptions.Compiled | RegexOptions.CultureInvariant);
    private static readonly Regex UsingRegex = new(@"^\s*using\s+(?:(?<static>static)\s+)?(?:(?<alias>[A-Za-z_]\w*)\s*=\s*)?(?<name>[A-Za-z_][\w\.]*(?:<[^>]+>)?)(?:\s*;\s*)$", RegexOptions.Compiled | RegexOptions.CultureInvariant);
    private static readonly Regex TypeRegex = new(@"^\s*(?:(?<mods>(?:public|private|protected|internal|static|abstract|sealed|partial|readonly|unsafe|new)\s+)+)?(?<kind>class|struct|interface|enum|record(?:\s+(?:class|struct))?)\s+(?<name>[A-Za-z_]\w*(?:<[^>{]+>)?)", RegexOptions.Compiled | RegexOptions.CultureInvariant);
    private static readonly Regex MethodRegex = new(@"^\s*(?:(?<mods>(?:public|private|protected|internal|static|virtual|override|abstract|async|sealed|partial|extern|new|unsafe|readonly)\s+)+)?(?<returnType>[A-Za-z_][\w<>\[\]\.,\?\s]*?)\s+(?<name>[A-Za-z_]\w*)\s*(?:<(?<generic>[^>]+)>)?\s*\((?<parameters>[^\)]*)\)\s*(?:\{|=>|where\b|;)", RegexOptions.Compiled | RegexOptions.CultureInvariant);

    public static CSharpFileReadModel Read(string path)
    {
        var lines = File.ReadAllLines(path);
        string? namespaceName = null;
        var usings = new List<string>();
        var types = new List<CSharpTypeSummary>();
        var methods = new List<CSharpMethodSummary>();
        string? currentType = null;

        for (var index = 0; index < lines.Length; index++)
        {
            var line = lines[index];
            var trimmed = line.Trim();

            if (string.IsNullOrWhiteSpace(trimmed) || trimmed.StartsWith("//", StringComparison.Ordinal))
            {
                continue;
            }

            var namespaceMatch = NamespaceRegex.Match(trimmed);
            if (namespaceMatch.Success)
            {
                namespaceName = namespaceMatch.Groups["name"].Value;
                continue;
            }

            var usingMatch = UsingRegex.Match(trimmed);
            if (usingMatch.Success)
            {
                usings.Add(trimmed);
                continue;
            }

            var typeMatch = TypeRegex.Match(trimmed);
            if (typeMatch.Success)
            {
                var modifiers = ParseModifiers(typeMatch.Groups["mods"].Value);
                var kind = NormalizeTypeKind(typeMatch.Groups["kind"].Value);
                var name = typeMatch.Groups["name"].Value;
                currentType = name;
                types.Add(new CSharpTypeSummary(kind, name, modifiers, index + 1, line.IndexOf(name, StringComparison.Ordinal) + 1));
                continue;
            }

            var methodMatch = MethodRegex.Match(trimmed);
            if (methodMatch.Success)
            {
                var modifiers = ParseModifiers(methodMatch.Groups["mods"].Value);
                var methodName = methodMatch.Groups["name"].Value;
                var returnType = methodMatch.Groups["returnType"].Value.Trim();
                var parameters = methodMatch.Groups["parameters"].Value.Trim();
                methods.Add(new CSharpMethodSummary(
                    Name: methodName,
                    ReturnType: returnType,
                    Parameters: parameters,
                    Modifiers: modifiers,
                    Line: index + 1,
                    Column: line.IndexOf(methodName, StringComparison.Ordinal) + 1,
                    ContainingType: currentType));
            }
        }

        return new CSharpFileReadModel(
            Path: Path.GetFullPath(path),
            Namespace: namespaceName,
            Usings: usings,
            Types: types,
            Methods: methods);
    }

    private static IReadOnlyList<string> ParseModifiers(string rawModifiers)
    {
        if (string.IsNullOrWhiteSpace(rawModifiers))
        {
            return Array.Empty<string>();
        }

        return rawModifiers.Split(' ', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
    }

    private static string NormalizeTypeKind(string kind)
    {
        return kind.Replace("record ", "record", StringComparison.Ordinal).Trim();
    }
}
