namespace GodotDotnetMcp.DotnetBridge;

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
    IReadOnlyList<CSharpMethodSummary> Methods,
    string SemanticRuntime);

internal static class CSharpFileReader
{
    public static CSharpFileReadModel Read(string path)
    {
        return ReadSource(path, File.ReadAllText(path));
    }

    public static CSharpFileReadModel ReadSource(string path, string sourceText)
    {
        var readModel = GodotDotnetMcp.PluginRuntime.Roslyn.PluginRoslynSyntaxCore.Read(path, sourceText);
        var types = readModel.Types
            .Select(type => new CSharpTypeSummary(type.Kind, type.Name, type.Modifiers, type.Line, type.Column))
            .ToArray();
        var methods = readModel.Methods
            .Select(method => new CSharpMethodSummary(
                method.Name,
                method.ReturnType,
                string.Join(", ", method.Parameters),
                method.Modifiers,
                method.Line,
                method.Column,
                method.ContainingType))
            .ToArray();

        return new CSharpFileReadModel(
            Path: Path.GetFullPath(path),
            Namespace: string.IsNullOrWhiteSpace(readModel.Namespace) ? null : readModel.Namespace,
            Usings: readModel.Usings,
            Types: types,
            Methods: methods,
            SemanticRuntime: "Roslyn");
    }
}
