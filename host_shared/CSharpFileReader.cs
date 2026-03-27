using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp;
using Microsoft.CodeAnalysis.CSharp.Syntax;
using Microsoft.CodeAnalysis.Text;

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
    public static CSharpFileReadModel Read(string path)
    {
        var sourceText = File.ReadAllText(path);
        var syntaxTree = CSharpSyntaxTree.ParseText(
            sourceText,
            new CSharpParseOptions(LanguageVersion.Preview));
        var root = syntaxTree.GetCompilationUnitRoot();

        var namespaceName = root.DescendantNodes()
            .OfType<BaseNamespaceDeclarationSyntax>()
            .Select(node => node.Name.ToString())
            .FirstOrDefault();

        var usings = root.DescendantNodes(descendIntoTrivia: false)
            .OfType<UsingDirectiveSyntax>()
            .Select(usingDirective => usingDirective.ToFullString().Trim())
            .Where(text => !string.IsNullOrWhiteSpace(text))
            .ToArray();

        var types = root.DescendantNodes(descendIntoTrivia: false)
            .OfType<BaseTypeDeclarationSyntax>()
            .Select(typeNode => BuildTypeSummary(syntaxTree, typeNode))
            .ToArray();

        var methods = root.DescendantNodes(descendIntoTrivia: false)
            .OfType<MethodDeclarationSyntax>()
            .Select(methodNode => BuildMethodSummary(syntaxTree, methodNode))
            .ToArray();

        return new CSharpFileReadModel(
            Path: Path.GetFullPath(path),
            Namespace: namespaceName,
            Usings: usings,
            Types: types,
            Methods: methods);
    }

    private static CSharpTypeSummary BuildTypeSummary(SyntaxTree syntaxTree, BaseTypeDeclarationSyntax typeNode)
    {
        var (line, column) = GetLineAndColumn(syntaxTree, typeNode.Identifier.Span);
        return new CSharpTypeSummary(
            Kind: GetTypeKind(typeNode),
            Name: GetTypeName(typeNode),
            Modifiers: typeNode.Modifiers.Select(token => token.Text).ToArray(),
            Line: line,
            Column: column);
    }

    private static CSharpMethodSummary BuildMethodSummary(SyntaxTree syntaxTree, MethodDeclarationSyntax methodNode)
    {
        var (line, column) = GetLineAndColumn(syntaxTree, methodNode.Identifier.Span);
        var containingType = methodNode.Ancestors()
            .OfType<BaseTypeDeclarationSyntax>()
            .Select(GetTypeName)
            .FirstOrDefault();

        return new CSharpMethodSummary(
            Name: methodNode.Identifier.Text,
            ReturnType: methodNode.ReturnType.ToString().Trim(),
            Parameters: string.Join(", ", methodNode.ParameterList.Parameters.Select(parameter => parameter.ToString().Trim())),
            Modifiers: methodNode.Modifiers.Select(token => token.Text).ToArray(),
            Line: line,
            Column: column,
            ContainingType: containingType);
    }

    private static string GetTypeKind(BaseTypeDeclarationSyntax typeNode)
    {
        return typeNode switch
        {
            ClassDeclarationSyntax => "class",
            StructDeclarationSyntax => "struct",
            InterfaceDeclarationSyntax => "interface",
            EnumDeclarationSyntax => "enum",
            RecordDeclarationSyntax => "record",
            _ => typeNode.Kind().ToString(),
        };
    }

    private static string GetTypeName(BaseTypeDeclarationSyntax typeNode)
    {
        return typeNode switch
        {
            TypeDeclarationSyntax declaration when declaration.TypeParameterList is not null
                => $"{declaration.Identifier.Text}{declaration.TypeParameterList}",
            _ => typeNode.Identifier.Text,
        };
    }

    private static (int Line, int Column) GetLineAndColumn(SyntaxTree syntaxTree, TextSpan span)
    {
        var position = syntaxTree.GetLineSpan(span).StartLinePosition;
        return (position.Line + 1, position.Character + 1);
    }
}
