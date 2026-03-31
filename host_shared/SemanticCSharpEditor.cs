using System.Text;
using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp;
using Microsoft.CodeAnalysis.CSharp.Syntax;

namespace GodotDotnetMcp.HostShared;

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

internal static class SemanticCSharpEditor
{
    public static string UpsertMethod(string text, SemanticMemberPatch patch, out PatchOperationResult result)
    {
        var syntaxTree = CSharpSyntaxTree.ParseText(text, cancellationToken: default);
        var root = syntaxTree.GetRoot();

        var typeDeclaration = root.DescendantNodes()
            .OfType<TypeDeclarationSyntax>()
            .FirstOrDefault(t => t.Identifier.Text == patch.TypeName && IsTypeKind(t));

        if (typeDeclaration == null)
        {
            throw new BridgeToolException($"Type '{patch.TypeName}' was not found.");
        }

        var existingMethod = FindMethodDeclaration(typeDeclaration, patch);
        if (existingMethod != null)
        {
            var newMethod = BuildMethodDeclaration(patch);
            var newRoot = root.ReplaceNode(existingMethod, newMethod);
            var newText = newRoot.ToFullString();
            result = new PatchOperationResult(
                Kind: "method_upsert",
                Target: $"{patch.TypeName}.{patch.MemberName}",
                MatchCount: 1,
                AppliedCount: 1,
                Note: "Updated existing method.");
            return newText;
        }

        var newMethodDeclaration = BuildMethodDeclaration(patch);
        var newRootWithInsert = InsertMember(root, typeDeclaration, newMethodDeclaration);
        var updatedText = newRootWithInsert.ToFullString();
        result = new PatchOperationResult(
            Kind: "method_upsert",
            Target: $"{patch.TypeName}.{patch.MemberName}",
            MatchCount: 0,
            AppliedCount: 1,
            Note: "Added new method.");
        return updatedText;
    }

    public static string RemoveMethod(string text, string typeName, string memberName, IReadOnlyList<string> parameters, string? signatureHint, out PatchOperationResult result)
    {
        var syntaxTree = CSharpSyntaxTree.ParseText(text, cancellationToken: default);
        var root = syntaxTree.GetRoot();

        var typeDeclaration = root.DescendantNodes()
            .OfType<TypeDeclarationSyntax>()
            .FirstOrDefault(t => t.Identifier.Text == typeName && IsTypeKind(t));

        if (typeDeclaration == null)
        {
            throw new BridgeToolException($"Type '{typeName}' was not found.");
        }

        var patch = new SemanticMemberPatch(
            TypeName: typeName,
            MemberName: memberName,
            Modifiers: Array.Empty<string>(),
            ReturnType: null,
            Parameters: parameters,
            Body: null,
            FieldType: null,
            Initializer: null,
            SignatureHint: signatureHint);

        var existingMethod = FindMethodDeclaration(typeDeclaration, patch);
        if (existingMethod == null)
        {
            throw new BridgeToolException($"Method '{memberName}' was not found in type '{typeName}'.");
        }

        var newRoot = root.RemoveNode(existingMethod, SyntaxRemoveOptions.KeepNoTrivia);
        var newText = newRoot!.ToFullString();
        result = new PatchOperationResult(
            Kind: "method_remove",
            Target: $"{typeName}.{memberName}",
            MatchCount: 1,
            AppliedCount: 1,
            Note: "Removed existing method.");
        return newText;
    }

    public static string UpsertField(string text, SemanticMemberPatch patch, out PatchOperationResult result)
    {
        if (string.IsNullOrWhiteSpace(patch.FieldType))
        {
            throw new BridgeToolException("fieldType is required for field upsert.");
        }

        var syntaxTree = CSharpSyntaxTree.ParseText(text, cancellationToken: default);
        var root = syntaxTree.GetRoot();

        var typeDeclaration = root.DescendantNodes()
            .OfType<TypeDeclarationSyntax>()
            .FirstOrDefault(t => t.Identifier.Text == patch.TypeName && IsTypeKind(t));

        if (typeDeclaration == null)
        {
            throw new BridgeToolException($"Type '{patch.TypeName}' was not found.");
        }

        var existingField = FindFieldDeclaration(typeDeclaration, patch);
        if (existingField != null)
        {
            var newField = BuildFieldDeclaration(patch);
            var newRoot = root.ReplaceNode(existingField, newField);
            var newText = newRoot.ToFullString();
            result = new PatchOperationResult(
                Kind: "field_upsert",
                Target: $"{patch.TypeName}.{patch.MemberName}",
                MatchCount: 1,
                AppliedCount: 1,
                Note: "Updated existing field.");
            return newText;
        }

        var newFieldDeclaration = BuildFieldDeclaration(patch);
        var newRootWithInsert = InsertMember(root, typeDeclaration, newFieldDeclaration);
        var updatedText = newRootWithInsert.ToFullString();
        result = new PatchOperationResult(
            Kind: "field_upsert",
            Target: $"{patch.TypeName}.{patch.MemberName}",
            MatchCount: 0,
            AppliedCount: 1,
            Note: "Added new field.");
        return updatedText;
    }

    public static string RemoveField(string text, string typeName, string memberName, string? signatureHint, out PatchOperationResult result)
    {
        var syntaxTree = CSharpSyntaxTree.ParseText(text, cancellationToken: default);
        var root = syntaxTree.GetRoot();

        var typeDeclaration = root.DescendantNodes()
            .OfType<TypeDeclarationSyntax>()
            .FirstOrDefault(t => t.Identifier.Text == typeName && IsTypeKind(t));

        if (typeDeclaration == null)
        {
            throw new BridgeToolException($"Type '{typeName}' was not found.");
        }

        var patch = new SemanticMemberPatch(
            TypeName: typeName,
            MemberName: memberName,
            Modifiers: Array.Empty<string>(),
            ReturnType: null,
            Parameters: Array.Empty<string>(),
            Body: null,
            FieldType: null,
            Initializer: null,
            SignatureHint: signatureHint);

        var existingField = FindFieldDeclaration(typeDeclaration, patch);
        if (existingField == null)
        {
            throw new BridgeToolException($"Field '{memberName}' was not found in type '{typeName}'.");
        }

        var newRoot = root.RemoveNode(existingField, SyntaxRemoveOptions.KeepNoTrivia);
        var newText = newRoot!.ToFullString();
        result = new PatchOperationResult(
            Kind: "field_remove",
            Target: $"{typeName}.{memberName}",
            MatchCount: 1,
            AppliedCount: 1,
            Note: "Removed existing field.");
        return newText;
    }

    private static SyntaxNode InsertMember(SyntaxNode root, TypeDeclarationSyntax typeDeclaration, MemberDeclarationSyntax newMember)
    {
        if (typeDeclaration.Members.Count == 0)
        {
            return root.ReplaceNode(typeDeclaration, typeDeclaration.WithMembers(new SyntaxList<MemberDeclarationSyntax>(newMember)));
        }

        var lastMember = typeDeclaration.Members.Last();
        var newMembers = typeDeclaration.Members.Replace(lastMember, lastMember);
        newMembers = newMembers.Add(newMember);
        return root.ReplaceNode(typeDeclaration, typeDeclaration.WithMembers(newMembers));
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

    private static MethodDeclarationSyntax? FindMethodDeclaration(TypeDeclarationSyntax typeDeclaration, SemanticMemberPatch patch)
    {
        var candidates = typeDeclaration.Members
            .OfType<MethodDeclarationSyntax>()
            .Where(m => m.Identifier.Text == patch.MemberName)
            .ToList();

        if (candidates.Count == 0)
        {
            return null;
        }

        if (patch.SignatureHint != null)
        {
            var hinted = candidates.Where(m => m.ToFullString().Contains(patch.SignatureHint, StringComparison.Ordinal)).ToList();
            if (hinted.Count > 0)
            {
                candidates = hinted;
            }
        }

        if (patch.Parameters.Count > 0)
        {
            var matched = candidates.Where(m => ParametersMatch(m.ParameterList, patch.Parameters)).ToList();
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

        for (var i = 0; i < parameters.Count; i++)
        {
            var paramText = parameters[i].Trim();
            var paramSyntax = parameterList.Parameters[i];
            var fullParamText = paramSyntax.Type != null
                ? $"{paramSyntax.Type.ToFullString().Trim()} {paramSyntax.Identifier.Text}"
                : paramSyntax.Identifier.Text;

            if (!fullParamText.Contains(paramText, StringComparison.Ordinal) &&
                !paramText.Contains(fullParamText, StringComparison.Ordinal))
            {
                return false;
            }
        }

        return true;
    }

    private static FieldDeclarationSyntax? FindFieldDeclaration(TypeDeclarationSyntax typeDeclaration, SemanticMemberPatch patch)
    {
        var candidates = typeDeclaration.Members
            .OfType<FieldDeclarationSyntax>()
            .Where(f => f.Declaration.Variables.Count > 0 &&
                        f.Declaration.Variables[0].Identifier.Text == patch.MemberName)
            .ToList();

        if (candidates.Count == 0)
        {
            return null;
        }

        if (patch.SignatureHint != null)
        {
            var hinted = candidates.Where(f => f.ToFullString().Contains(patch.SignatureHint, StringComparison.Ordinal)).ToList();
            if (hinted.Count > 0)
            {
                candidates = hinted;
            }
        }

        return candidates.FirstOrDefault();
    }

    private static MethodDeclarationSyntax BuildMethodDeclaration(SemanticMemberPatch patch)
    {
        var modifiers = patch.Modifiers.Count > 0
            ? SyntaxFactory.TokenList(patch.Modifiers.Select(m => SyntaxFactory.Token(GetModifierKind(m))))
            : SyntaxFactory.TokenList();

        var returnType = string.IsNullOrWhiteSpace(patch.ReturnType)
            ? SyntaxFactory.PredefinedType(SyntaxFactory.Token(SyntaxKind.VoidKeyword))
            : SyntaxFactory.ParseTypeName(patch.ReturnType.Trim());

        var parameterList = patch.Parameters.Count > 0
            ? SyntaxFactory.ParameterList(SyntaxFactory.SeparatedList(patch.Parameters.Select(p => SyntaxFactory.Parameter(SyntaxFactory.Identifier(p)))))
            : SyntaxFactory.ParameterList();

        BlockSyntax body;
        if (!string.IsNullOrWhiteSpace(patch.Body))
        {
            var bodyTree = CSharpSyntaxTree.ParseText("void __f() { " + patch.Body + " }", cancellationToken: default);
            var bodyRoot = bodyTree.GetRoot();
            var methodDecl = bodyRoot.DescendantNodes().OfType<MethodDeclarationSyntax>().First();
            body = methodDecl.Body ?? SyntaxFactory.Block();
        }
        else
        {
            body = SyntaxFactory.Block();
        }

        return SyntaxFactory.MethodDeclaration(returnType, patch.MemberName)
            .WithModifiers(modifiers)
            .WithParameterList(parameterList)
            .WithBody(body);
    }

    private static SyntaxKind GetModifierKind(string modifier)
    {
        return modifier.Trim().ToLowerInvariant() switch
        {
            "public" => SyntaxKind.PublicKeyword,
            "private" => SyntaxKind.PrivateKeyword,
            "protected" => SyntaxKind.ProtectedKeyword,
            "internal" => SyntaxKind.InternalKeyword,
            "static" => SyntaxKind.StaticKeyword,
            "virtual" => SyntaxKind.VirtualKeyword,
            "override" => SyntaxKind.OverrideKeyword,
            "abstract" => SyntaxKind.AbstractKeyword,
            "readonly" => SyntaxKind.ReadOnlyKeyword,
            "sealed" => SyntaxKind.SealedKeyword,
            "async" => SyntaxKind.AsyncKeyword,
            "partial" => SyntaxKind.PartialKeyword,
            "extern" => SyntaxKind.ExternKeyword,
            "unsafe" => SyntaxKind.UnsafeKeyword,
            "volatile" => SyntaxKind.VolatileKeyword,
            "new" => SyntaxKind.NewKeyword,
            _ => SyntaxKind.None,
        };
    }

    private static FieldDeclarationSyntax BuildFieldDeclaration(SemanticMemberPatch patch)
    {
        var modifiers = patch.Modifiers.Count > 0
            ? SyntaxFactory.TokenList(patch.Modifiers.Select(m => SyntaxFactory.Token(GetModifierKind(m))))
            : SyntaxFactory.TokenList(SyntaxFactory.Token(SyntaxKind.PrivateKeyword));

        var fieldType = SyntaxFactory.ParseTypeName(patch.FieldType!.Trim());
        var variable = SyntaxFactory.VariableDeclarator(patch.MemberName);

        if (!string.IsNullOrWhiteSpace(patch.Initializer))
        {
            variable = variable.WithInitializer(SyntaxFactory.EqualsValueClause(SyntaxFactory.ParseExpression(patch.Initializer.Trim())));
        }

        var declaration = SyntaxFactory.VariableDeclaration(fieldType, SyntaxFactory.SingletonSeparatedList(variable));
        return SyntaxFactory.FieldDeclaration(declaration).WithModifiers(modifiers);
    }
}