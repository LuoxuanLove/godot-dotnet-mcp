using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp;
using Microsoft.CodeAnalysis.CSharp.Syntax;
using Microsoft.CodeAnalysis.Text;

namespace GodotDotnetMcp.PluginRuntime.Roslyn;

internal sealed record PatchOperationResult(
    string Kind,
    string Target,
    int MatchCount,
    int AppliedCount,
    string? Note);

internal sealed class BridgeToolException : Exception
{
    public BridgeToolException(string message)
        : base(message)
    {
    }
}

internal sealed record PluginRoslynTypeSummary(
    string Kind,
    string Name,
    string Namespace,
    string BaseType,
    bool Partial,
    IReadOnlyList<string> Modifiers,
    int Line,
    int Column);

internal sealed record PluginRoslynMethodSummary(
    string Name,
    string ReturnType,
    IReadOnlyList<string> Parameters,
    IReadOnlyList<string> Modifiers,
    int Line,
    int Column,
    string ContainingType);

internal sealed record PluginRoslynParseError(
    string Severity,
    string Code,
    string Message,
    int Line,
    int Column);

internal sealed record PluginRoslynReadModel(
    string Path,
    string Namespace,
    IReadOnlyList<string> Usings,
    IReadOnlyList<PluginRoslynTypeSummary> Types,
    IReadOnlyList<PluginRoslynMethodSummary> Methods,
    IReadOnlyList<PluginRoslynParseError> ParseErrors,
    CompilationUnitSyntax Root);

internal sealed record PluginRoslynMemberPatch(
    string TypeName,
    string MemberName,
    IReadOnlyList<string> Modifiers,
    string? ReturnType,
    IReadOnlyList<string> Parameters,
    string? Body,
    string? FieldType,
    string? Initializer,
    string? SignatureHint,
    bool Exported);

internal static class PluginRoslynSyntaxCore
{
    public static PluginRoslynReadModel Read(string path, string sourceText)
    {
        var syntaxTree = ParseSource(path, sourceText);
        var root = syntaxTree.GetCompilationUnitRoot();

        var namespaceName = root.DescendantNodes()
            .OfType<BaseNamespaceDeclarationSyntax>()
            .Select(node => node.Name.ToString())
            .FirstOrDefault() ?? string.Empty;

        var usings = root.Usings
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

        var parseErrors = syntaxTree.GetDiagnostics()
            .Where(diagnostic => diagnostic.Severity == DiagnosticSeverity.Error)
            .Select(BuildParseError)
            .ToArray();

        return new PluginRoslynReadModel(
            Path: string.IsNullOrWhiteSpace(path) ? string.Empty : Path.GetFullPath(path),
            Namespace: namespaceName,
            Usings: usings,
            Types: types,
            Methods: methods,
            ParseErrors: parseErrors,
            Root: root);
    }

    public static string UpsertMethod(string text, PluginRoslynMemberPatch patch, out PatchOperationResult result)
    {
        var syntaxTree = ParseSource(string.Empty, text);
        var root = syntaxTree.GetCompilationUnitRoot();
        var typeDeclaration = FindTypeDeclaration(root, patch.TypeName);
        var existingMethod = FindMethodDeclaration(typeDeclaration, patch);
        var newMethod = BuildMethodDeclaration(patch, ResolveMemberIndent(typeDeclaration, syntaxTree));

        if (existingMethod is not null)
        {
            var updatedMethod = newMethod
                .WithLeadingTrivia(existingMethod.GetLeadingTrivia())
                .WithTrailingTrivia(existingMethod.GetTrailingTrivia());
            var newRoot = root.ReplaceNode(existingMethod, updatedMethod);
            result = new PatchOperationResult(
                Kind: "method_upsert",
                Target: $"{patch.TypeName}.{patch.MemberName}",
                MatchCount: 1,
                AppliedCount: 1,
                Note: "Updated existing method.");
            return newRoot.ToFullString();
        }

        var insertedRoot = InsertMember(root, typeDeclaration, PrepareInsertedMember(newMethod, typeDeclaration, syntaxTree));
        result = new PatchOperationResult(
            Kind: "method_upsert",
            Target: $"{patch.TypeName}.{patch.MemberName}",
            MatchCount: 0,
            AppliedCount: 1,
            Note: "Added new method.");
        return insertedRoot.ToFullString();
    }

    public static string RemoveMethod(string text, string typeName, string memberName, IReadOnlyList<string> parameters, string? signatureHint, out PatchOperationResult result)
    {
        var syntaxTree = ParseSource(string.Empty, text);
        var root = syntaxTree.GetCompilationUnitRoot();
        var typeDeclaration = FindTypeDeclaration(root, typeName);
        var patch = new PluginRoslynMemberPatch(
            TypeName: typeName,
            MemberName: memberName,
            Modifiers: Array.Empty<string>(),
            ReturnType: null,
            Parameters: parameters,
            Body: null,
            FieldType: null,
            Initializer: null,
            SignatureHint: signatureHint,
            Exported: false);

        var existingMethod = FindMethodDeclaration(typeDeclaration, patch);
        if (existingMethod is null)
        {
            throw new BridgeToolException($"Method '{memberName}' was not found in type '{typeName}'.");
        }

        var newRoot = root.RemoveNode(existingMethod, SyntaxRemoveOptions.KeepNoTrivia);
        result = new PatchOperationResult(
            Kind: "method_remove",
            Target: $"{typeName}.{memberName}",
            MatchCount: 1,
            AppliedCount: 1,
            Note: "Removed existing method.");
        return newRoot!.ToFullString();
    }

    public static string UpsertField(string text, PluginRoslynMemberPatch patch, out PatchOperationResult result)
    {
        if (string.IsNullOrWhiteSpace(patch.FieldType))
        {
            throw new BridgeToolException("fieldType is required for field upsert.");
        }

        var syntaxTree = ParseSource(string.Empty, text);
        var root = syntaxTree.GetCompilationUnitRoot();
        var typeDeclaration = FindTypeDeclaration(root, patch.TypeName);
        var existingField = FindFieldDeclaration(typeDeclaration, patch);
        var newField = BuildFieldDeclaration(patch, ResolveMemberIndent(typeDeclaration, syntaxTree));

        if (existingField is not null)
        {
            var updatedField = newField
                .WithLeadingTrivia(existingField.GetLeadingTrivia())
                .WithTrailingTrivia(existingField.GetTrailingTrivia());
            var newRoot = root.ReplaceNode(existingField, updatedField);
            result = new PatchOperationResult(
                Kind: "field_upsert",
                Target: $"{patch.TypeName}.{patch.MemberName}",
                MatchCount: 1,
                AppliedCount: 1,
                Note: "Updated existing field.");
            return newRoot.ToFullString();
        }

        var insertedRoot = InsertMember(root, typeDeclaration, PrepareInsertedMember(newField, typeDeclaration, syntaxTree));
        result = new PatchOperationResult(
            Kind: "field_upsert",
            Target: $"{patch.TypeName}.{patch.MemberName}",
            MatchCount: 0,
            AppliedCount: 1,
            Note: "Added new field.");
        return insertedRoot.ToFullString();
    }

    public static string RemoveField(string text, string typeName, string memberName, string? signatureHint, out PatchOperationResult result)
    {
        var syntaxTree = ParseSource(string.Empty, text);
        var root = syntaxTree.GetCompilationUnitRoot();
        var typeDeclaration = FindTypeDeclaration(root, typeName);
        var patch = new PluginRoslynMemberPatch(
            TypeName: typeName,
            MemberName: memberName,
            Modifiers: Array.Empty<string>(),
            ReturnType: null,
            Parameters: Array.Empty<string>(),
            Body: null,
            FieldType: null,
            Initializer: null,
            SignatureHint: signatureHint,
            Exported: false);

        var existingField = FindFieldDeclaration(typeDeclaration, patch);
        if (existingField is null)
        {
            throw new BridgeToolException($"Field '{memberName}' was not found in type '{typeName}'.");
        }

        var newRoot = root.RemoveNode(existingField, SyntaxRemoveOptions.KeepNoTrivia);
        result = new PatchOperationResult(
            Kind: "field_remove",
            Target: $"{typeName}.{memberName}",
            MatchCount: 1,
            AppliedCount: 1,
            Note: "Removed existing field.");
        return newRoot!.ToFullString();
    }

    public static string ReplaceMethodBody(string text, string typeName, string memberName, IReadOnlyList<string> parameters, string? signatureHint, string? body, out PatchOperationResult result)
    {
        var syntaxTree = ParseSource(string.Empty, text);
        var root = syntaxTree.GetCompilationUnitRoot();
        var typeDeclaration = FindTypeDeclaration(root, typeName);
        var patch = new PluginRoslynMemberPatch(
            TypeName: typeName,
            MemberName: memberName,
            Modifiers: Array.Empty<string>(),
            ReturnType: null,
            Parameters: parameters,
            Body: body,
            FieldType: null,
            Initializer: null,
            SignatureHint: signatureHint,
            Exported: false);

        var existingMethod = FindMethodDeclaration(typeDeclaration, patch);
        if (existingMethod is null)
        {
            throw new BridgeToolException($"Method '{memberName}' was not found in type '{typeName}'.");
        }

        var replacementPatch = new PluginRoslynMemberPatch(
            TypeName: typeName,
            MemberName: memberName,
            Modifiers: existingMethod.Modifiers.Select(token => token.Text).ToArray(),
            ReturnType: existingMethod.ReturnType.ToString().Trim(),
            Parameters: existingMethod.ParameterList.Parameters.Select(parameter => parameter.ToString().Trim()).ToArray(),
            Body: body,
            FieldType: null,
            Initializer: null,
            SignatureHint: signatureHint,
            Exported: false);

        var replacementMethod = BuildMethodDeclaration(replacementPatch, ResolveMemberIndent(typeDeclaration, syntaxTree))
            .WithAttributeLists(existingMethod.AttributeLists)
            .WithLeadingTrivia(existingMethod.GetLeadingTrivia())
            .WithTrailingTrivia(existingMethod.GetTrailingTrivia())
            .WithExplicitInterfaceSpecifier(existingMethod.ExplicitInterfaceSpecifier)
            .WithConstraintClauses(existingMethod.ConstraintClauses)
            .WithTypeParameterList(existingMethod.TypeParameterList);

        var newRoot = root.ReplaceNode(existingMethod, replacementMethod);
        result = new PatchOperationResult(
            Kind: "method_body_replace",
            Target: $"{typeName}.{memberName}",
            MatchCount: 1,
            AppliedCount: 1,
            Note: "Replaced existing method body.");
        return newRoot.ToFullString();
    }

    public static string RemoveProperty(string text, string typeName, string memberName, string? signatureHint, out PatchOperationResult result)
    {
        var syntaxTree = ParseSource(string.Empty, text);
        var root = syntaxTree.GetCompilationUnitRoot();
        var typeDeclaration = FindTypeDeclaration(root, typeName);
        var propertyDeclaration = FindPropertyDeclaration(typeDeclaration, memberName, signatureHint);
        if (propertyDeclaration is null)
        {
            throw new BridgeToolException($"Property '{memberName}' was not found in type '{typeName}'.");
        }

        var newRoot = root.RemoveNode(propertyDeclaration, SyntaxRemoveOptions.KeepNoTrivia);
        result = new PatchOperationResult(
            Kind: "property_remove",
            Target: $"{typeName}.{memberName}",
            MatchCount: 1,
            AppliedCount: 1,
            Note: "Removed existing property.");
        return newRoot!.ToFullString();
    }

    public static string RenameMethod(string text, string typeName, string memberName, string newName, IReadOnlyList<string> parameters, string? signatureHint, out PatchOperationResult result)
    {
        var syntaxTree = ParseSource(string.Empty, text);
        var root = syntaxTree.GetCompilationUnitRoot();
        var typeDeclaration = FindTypeDeclaration(root, typeName);
        var patch = new PluginRoslynMemberPatch(
            TypeName: typeName,
            MemberName: memberName,
            Modifiers: Array.Empty<string>(),
            ReturnType: null,
            Parameters: parameters,
            Body: null,
            FieldType: null,
            Initializer: null,
            SignatureHint: signatureHint,
            Exported: false);

        var existingMethod = FindMethodDeclaration(typeDeclaration, patch);
        if (existingMethod is null)
        {
            throw new BridgeToolException($"Method '{memberName}' was not found in type '{typeName}'.");
        }

        var renamedMethod = existingMethod.WithIdentifier(SyntaxFactory.Identifier(existingMethod.Identifier.LeadingTrivia, newName, existingMethod.Identifier.TrailingTrivia));
        var newRoot = root.ReplaceNode(existingMethod, renamedMethod);
        result = new PatchOperationResult(
            Kind: "method_rename",
            Target: $"{typeName}.{memberName}",
            MatchCount: 1,
            AppliedCount: 1,
            Note: $"Renamed method to '{newName}'.");
        return newRoot.ToFullString();
    }

    public static string RenameField(string text, string typeName, string memberName, string newName, string? signatureHint, out PatchOperationResult result)
    {
        var syntaxTree = ParseSource(string.Empty, text);
        var root = syntaxTree.GetCompilationUnitRoot();
        var typeDeclaration = FindTypeDeclaration(root, typeName);
        var patch = new PluginRoslynMemberPatch(
            TypeName: typeName,
            MemberName: memberName,
            Modifiers: Array.Empty<string>(),
            ReturnType: null,
            Parameters: Array.Empty<string>(),
            Body: null,
            FieldType: null,
            Initializer: null,
            SignatureHint: signatureHint,
            Exported: false);

        var existingField = FindFieldDeclaration(typeDeclaration, patch);
        if (existingField is null)
        {
            throw new BridgeToolException($"Field '{memberName}' was not found in type '{typeName}'.");
        }

        var variable = existingField.Declaration.Variables.First(item => item.Identifier.Text == memberName);
        var renamedVariable = variable.WithIdentifier(SyntaxFactory.Identifier(variable.Identifier.LeadingTrivia, newName, variable.Identifier.TrailingTrivia));
        var newField = existingField.ReplaceNode(variable, renamedVariable);
        var newRoot = root.ReplaceNode(existingField, newField);
        result = new PatchOperationResult(
            Kind: "field_rename",
            Target: $"{typeName}.{memberName}",
            MatchCount: 1,
            AppliedCount: 1,
            Note: $"Renamed field to '{newName}'.");
        return newRoot.ToFullString();
    }

    public static string RenameProperty(string text, string typeName, string memberName, string newName, string? signatureHint, out PatchOperationResult result)
    {
        var syntaxTree = ParseSource(string.Empty, text);
        var root = syntaxTree.GetCompilationUnitRoot();
        var typeDeclaration = FindTypeDeclaration(root, typeName);
        var propertyDeclaration = FindPropertyDeclaration(typeDeclaration, memberName, signatureHint);
        if (propertyDeclaration is null)
        {
            throw new BridgeToolException($"Property '{memberName}' was not found in type '{typeName}'.");
        }

        var renamedProperty = propertyDeclaration.WithIdentifier(SyntaxFactory.Identifier(propertyDeclaration.Identifier.LeadingTrivia, newName, propertyDeclaration.Identifier.TrailingTrivia));
        var newRoot = root.ReplaceNode(propertyDeclaration, renamedProperty);
        result = new PatchOperationResult(
            Kind: "property_rename",
            Target: $"{typeName}.{memberName}",
            MatchCount: 1,
            AppliedCount: 1,
            Note: $"Renamed property to '{newName}'.");
        return newRoot.ToFullString();
    }

    private static SyntaxTree ParseSource(string path, string sourceText)
    {
        return CSharpSyntaxTree.ParseText(
            sourceText,
            new CSharpParseOptions(LanguageVersion.Preview),
            path: path);
    }

    private static PluginRoslynTypeSummary BuildTypeSummary(SyntaxTree syntaxTree, BaseTypeDeclarationSyntax typeNode)
    {
        var (line, column) = GetLineAndColumn(syntaxTree, typeNode.Identifier.Span);
        return new PluginRoslynTypeSummary(
            Kind: GetTypeKind(typeNode),
            Name: GetTypeName(typeNode),
            Namespace: GetNamespace(typeNode),
            BaseType: typeNode.BaseList?.Types.FirstOrDefault()?.Type.ToString() ?? string.Empty,
            Partial: typeNode.Modifiers.Any(modifier => modifier.IsKind(SyntaxKind.PartialKeyword)),
            Modifiers: typeNode.Modifiers.Select(token => token.Text).ToArray(),
            Line: line,
            Column: column);
    }

    private static PluginRoslynMethodSummary BuildMethodSummary(SyntaxTree syntaxTree, MethodDeclarationSyntax methodNode)
    {
        var (line, column) = GetLineAndColumn(syntaxTree, methodNode.Identifier.Span);
        var containingType = methodNode.Ancestors()
            .OfType<BaseTypeDeclarationSyntax>()
            .Select(GetTypeName)
            .FirstOrDefault() ?? string.Empty;

        return new PluginRoslynMethodSummary(
            Name: methodNode.Identifier.Text,
            ReturnType: methodNode.ReturnType.ToString().Trim(),
            Parameters: methodNode.ParameterList.Parameters.Select(parameter => parameter.ToString().Trim()).ToArray(),
            Modifiers: methodNode.Modifiers.Select(token => token.Text).ToArray(),
            Line: line,
            Column: column,
            ContainingType: containingType);
    }

    private static PluginRoslynParseError BuildParseError(Diagnostic diagnostic)
    {
        var lineSpan = diagnostic.Location.GetLineSpan();
        var start = lineSpan.StartLinePosition;
        return new PluginRoslynParseError(
            Severity: diagnostic.Severity.ToString().ToLowerInvariant(),
            Code: diagnostic.Id,
            Message: diagnostic.GetMessage(),
            Line: start.Line + 1,
            Column: start.Character + 1);
    }

    private static TypeDeclarationSyntax FindTypeDeclaration(CompilationUnitSyntax root, string typeName)
    {
        var typeDeclaration = root.DescendantNodes()
            .OfType<TypeDeclarationSyntax>()
            .FirstOrDefault(type => IsTypeKind(type) && MatchesTypeName(type, typeName));

        return typeDeclaration ?? throw new BridgeToolException($"Type '{typeName}' was not found.");
    }

    private static bool MatchesTypeName(TypeDeclarationSyntax typeDeclaration, string typeName)
    {
        return string.Equals(typeDeclaration.Identifier.Text, typeName, StringComparison.Ordinal) ||
               string.Equals(GetTypeName(typeDeclaration), typeName, StringComparison.Ordinal);
    }

    private static bool IsTypeKind(TypeDeclarationSyntax typeDeclaration)
    {
        return typeDeclaration.Kind() switch
        {
            SyntaxKind.ClassDeclaration or
            SyntaxKind.StructDeclaration or
            SyntaxKind.RecordDeclaration or
            SyntaxKind.RecordStructDeclaration => true,
            _ => false,
        };
    }

    private static MethodDeclarationSyntax? FindMethodDeclaration(TypeDeclarationSyntax typeDeclaration, PluginRoslynMemberPatch patch)
    {
        var candidates = typeDeclaration.Members
            .OfType<MethodDeclarationSyntax>()
            .Where(method => method.Identifier.Text == patch.MemberName)
            .ToList();

        if (candidates.Count == 0)
        {
            return null;
        }

        if (!string.IsNullOrWhiteSpace(patch.SignatureHint))
        {
            var hinted = candidates
                .Where(method => method.ToFullString().Contains(patch.SignatureHint, StringComparison.Ordinal))
                .ToList();
            if (hinted.Count > 0)
            {
                candidates = hinted;
            }
        }

        if (patch.Parameters.Count > 0)
        {
            var matched = candidates
                .Where(method => ParametersMatch(method.ParameterList, patch.Parameters))
                .ToList();
            if (matched.Count > 0)
            {
                candidates = matched;
            }
        }

        return candidates.FirstOrDefault();
    }

    private static bool ParametersMatch(BaseParameterListSyntax parameterList, IReadOnlyList<string> parameters)
    {
        if (parameterList.Parameters.Count != parameters.Count)
        {
            return false;
        }

        for (var index = 0; index < parameters.Count; index++)
        {
            var actual = NormalizeText(parameterList.Parameters[index].ToString());
            var expected = NormalizeText(parameters[index]);
            if (!string.Equals(actual, expected, StringComparison.Ordinal) &&
                !actual.Contains(expected, StringComparison.Ordinal) &&
                !expected.Contains(actual, StringComparison.Ordinal))
            {
                return false;
            }
        }

        return true;
    }

    private static FieldDeclarationSyntax? FindFieldDeclaration(TypeDeclarationSyntax typeDeclaration, PluginRoslynMemberPatch patch)
    {
        var candidates = typeDeclaration.Members
            .OfType<FieldDeclarationSyntax>()
            .Where(field => field.Declaration.Variables.Any(variable => variable.Identifier.Text == patch.MemberName))
            .ToList();

        if (candidates.Count == 0)
        {
            return null;
        }

        if (!string.IsNullOrWhiteSpace(patch.SignatureHint))
        {
            var hinted = candidates
                .Where(field => field.ToFullString().Contains(patch.SignatureHint, StringComparison.Ordinal))
                .ToList();
            if (hinted.Count > 0)
            {
                candidates = hinted;
            }
        }

        return candidates.FirstOrDefault();
    }

    private static PropertyDeclarationSyntax? FindPropertyDeclaration(TypeDeclarationSyntax typeDeclaration, string memberName, string? signatureHint)
    {
        var candidates = typeDeclaration.Members
            .OfType<PropertyDeclarationSyntax>()
            .Where(property => property.Identifier.Text == memberName)
            .ToList();

        if (candidates.Count == 0)
        {
            return null;
        }

        if (!string.IsNullOrWhiteSpace(signatureHint))
        {
            var hinted = candidates
                .Where(property => property.ToFullString().Contains(signatureHint, StringComparison.Ordinal))
                .ToList();
            if (hinted.Count > 0)
            {
                candidates = hinted;
            }
        }

        return candidates.FirstOrDefault();
    }

    private static MethodDeclarationSyntax BuildMethodDeclaration(PluginRoslynMemberPatch patch, string indent)
    {
        var modifiers = patch.Modifiers.Count > 0 ? string.Join(' ', patch.Modifiers) + " " : string.Empty;
        var returnType = string.IsNullOrWhiteSpace(patch.ReturnType) ? "void" : patch.ReturnType!.Trim();
        var parameters = string.Join(", ", patch.Parameters.Select(parameter => parameter.Trim()));
        var bodyText = BuildMethodBody(patch.Body, indent + "    ");
        var source = new StringBuilder()
            .AppendLine("class __PluginRoslynWrapper")
            .AppendLine("{")
            .Append(indent)
            .Append(modifiers)
            .Append(returnType)
            .Append(' ')
            .Append(patch.MemberName)
            .Append('(')
            .Append(parameters)
            .AppendLine(")")
            .Append(indent)
            .AppendLine("{")
            .Append(bodyText)
            .Append(indent)
            .AppendLine("}")
            .AppendLine("}")
            .ToString();

        var wrapperRoot = ParseSource(string.Empty, source).GetCompilationUnitRoot();
        return wrapperRoot.DescendantNodes().OfType<MethodDeclarationSyntax>().First();
    }

    private static FieldDeclarationSyntax BuildFieldDeclaration(PluginRoslynMemberPatch patch, string indent)
    {
        var modifiers = patch.Modifiers.Count > 0 ? string.Join(' ', patch.Modifiers) + " " : "private ";
        var initializer = string.IsNullOrWhiteSpace(patch.Initializer) ? string.Empty : " = " + patch.Initializer!.Trim();
        var builder = new StringBuilder()
            .AppendLine("class __PluginRoslynWrapper")
            .AppendLine("{");
        if (patch.Exported)
        {
            builder
                .Append(indent)
                .AppendLine("[Export]");
        }
        var source = builder
            .Append(indent)
            .Append(modifiers)
            .Append(patch.FieldType!.Trim())
            .Append(' ')
            .Append(patch.MemberName)
            .Append(initializer)
            .AppendLine(";")
            .AppendLine("}")
            .ToString();

        var wrapperRoot = ParseSource(string.Empty, source).GetCompilationUnitRoot();
        return wrapperRoot.DescendantNodes().OfType<FieldDeclarationSyntax>().First();
    }

    private static string BuildMethodBody(string? body, string indent)
    {
        if (string.IsNullOrWhiteSpace(body))
        {
            return string.Empty;
        }

        var normalizedBody = body.Replace("\r\n", "\n", StringComparison.Ordinal).Trim('\n', '\r');
        var lines = normalizedBody.Split('\n');
        var builder = new StringBuilder();
        foreach (var line in lines)
        {
            builder.Append(indent);
            builder.AppendLine(line.TrimEnd());
        }

        return builder.ToString();
    }

    private static MemberDeclarationSyntax PrepareInsertedMember(MemberDeclarationSyntax newMember, TypeDeclarationSyntax typeDeclaration, SyntaxTree syntaxTree)
    {
        if (typeDeclaration.Members.Count > 0)
        {
            var template = typeDeclaration.Members.Last();
            return newMember
                .WithLeadingTrivia(template.GetLeadingTrivia())
                .WithTrailingTrivia(template.GetTrailingTrivia());
        }

        var indent = ResolveMemberIndent(typeDeclaration, syntaxTree);
        return newMember
            .WithLeadingTrivia(SyntaxFactory.CarriageReturnLineFeed, SyntaxFactory.Whitespace(indent))
            .WithTrailingTrivia(SyntaxFactory.CarriageReturnLineFeed);
    }

    private static CompilationUnitSyntax InsertMember(CompilationUnitSyntax root, TypeDeclarationSyntax typeDeclaration, MemberDeclarationSyntax newMember)
    {
        var updatedType = typeDeclaration.AddMembers(newMember);
        return root.ReplaceNode(typeDeclaration, updatedType);
    }

    private static string ResolveMemberIndent(TypeDeclarationSyntax typeDeclaration, SyntaxTree syntaxTree)
    {
        if (typeDeclaration.Members.Count > 0)
        {
            var triviaIndent = ExtractIndentation(typeDeclaration.Members[0].GetLeadingTrivia().ToFullString());
            if (!string.IsNullOrEmpty(triviaIndent))
            {
                return triviaIndent;
            }
        }

        var declarationIndent = ExtractLineIndentation(syntaxTree, typeDeclaration.SpanStart);
        return declarationIndent + "    ";
    }

    private static string ExtractLineIndentation(SyntaxTree syntaxTree, int position)
    {
        var sourceText = syntaxTree.GetText();
        var line = sourceText.Lines.GetLineFromPosition(position);
        var lineText = sourceText.ToString(TextSpan.FromBounds(line.Start, line.End));
        return ExtractIndentation(lineText);
    }

    private static string ExtractIndentation(string text)
    {
        var builder = new StringBuilder();
        for (var index = 0; index < text.Length; index++)
        {
            var ch = text[index];
            if (ch == ' ' || ch == '\t')
            {
                builder.Append(ch);
                continue;
            }

            if (ch == '\r' || ch == '\n')
            {
                builder.Clear();
                continue;
            }

            break;
        }

        return builder.ToString();
    }

    private static string NormalizeText(string value)
    {
        return string.Join(' ', value.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries));
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

    private static string GetNamespace(SyntaxNode node)
    {
        for (SyntaxNode? current = node.Parent; current is not null; current = current.Parent)
        {
            if (current is BaseNamespaceDeclarationSyntax namespaceSyntax)
            {
                return namespaceSyntax.Name.ToString();
            }
        }

        return string.Empty;
    }

    private static (int Line, int Column) GetLineAndColumn(SyntaxTree syntaxTree, TextSpan span)
    {
        var position = syntaxTree.GetLineSpan(span).StartLinePosition;
        return (position.Line + 1, position.Character + 1);
    }
}
