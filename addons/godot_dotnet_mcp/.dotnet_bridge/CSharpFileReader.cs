using System.Text.Json.Serialization;

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

internal sealed record CSharpExportSummary(
    string Name,
    [property: JsonPropertyName("member_type")] string MemberType,
    [property: JsonPropertyName("type_name")] string TypeName);

internal sealed record CSharpParseErrorSummary(string Severity, string Code, string Message, int Line, int Column);

internal sealed record CSharpFileReadModel(
    string Path,
    string? Namespace,
    IReadOnlyList<string> Usings,
    IReadOnlyList<CSharpTypeSummary> Types,
    IReadOnlyList<CSharpMethodSummary> Methods,
    IReadOnlyList<CSharpExportSummary> Exports,
    IReadOnlyList<CSharpParseErrorSummary> ParseErrors,
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
        var exports = readModel.Root.DescendantNodes()
            .OfType<Microsoft.CodeAnalysis.CSharp.Syntax.FieldDeclarationSyntax>()
            .Where(field => HasExportAttribute(field.AttributeLists))
            .SelectMany(field => field.Declaration.Variables.Select(variable => new CSharpExportSummary(
                variable.Identifier.Text,
                "field",
                field.Declaration.Type.ToString())))
            .Concat(readModel.Root.DescendantNodes()
                .OfType<Microsoft.CodeAnalysis.CSharp.Syntax.PropertyDeclarationSyntax>()
                .Where(property => HasExportAttribute(property.AttributeLists))
                .Select(property => new CSharpExportSummary(
                    property.Identifier.Text,
                    "property",
                    property.Type.ToString())))
            .ToArray();
        var parseErrors = readModel.ParseErrors
            .Select(error => new CSharpParseErrorSummary(error.Severity, error.Code, error.Message, error.Line, error.Column))
            .ToArray();

        return new CSharpFileReadModel(
            Path: Path.GetFullPath(path),
            Namespace: string.IsNullOrWhiteSpace(readModel.Namespace) ? null : readModel.Namespace,
            Usings: readModel.Usings,
            Types: types,
            Methods: methods,
            Exports: exports,
            ParseErrors: parseErrors,
            SemanticRuntime: "Roslyn");
    }

    private static bool HasExportAttribute(Microsoft.CodeAnalysis.SyntaxList<Microsoft.CodeAnalysis.CSharp.Syntax.AttributeListSyntax> attributeLists)
    {
        foreach (var attributeList in attributeLists)
        {
            foreach (var attribute in attributeList.Attributes)
            {
                var name = attribute.Name.ToString();
                if (name == "Export" ||
                    name == "ExportAttribute" ||
                    name.EndsWith(".Export", StringComparison.Ordinal) ||
                    name.EndsWith(".ExportAttribute", StringComparison.Ordinal))
                {
                    return true;
                }
            }
        }

        return false;
    }
}
