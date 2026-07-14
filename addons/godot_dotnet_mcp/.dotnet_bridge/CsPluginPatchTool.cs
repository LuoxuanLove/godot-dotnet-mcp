using System.Text.Json;
using GodotDotnetMcp.PluginRuntime.Roslyn;
using RuntimeBridgeException = GodotDotnetMcp.PluginRuntime.Roslyn.BridgeToolException;
using RuntimePatchOperationResult = GodotDotnetMcp.PluginRuntime.Roslyn.PatchOperationResult;

namespace GodotDotnetMcp.DotnetBridge;

internal sealed record PluginPatchResult(
    string Path,
    string SourceHash,
    bool DryRun,
    bool Written,
    string Action,
    string TypeName,
    string MemberName,
    BridgePatchOperationResult Operation,
    IReadOnlyList<CSharpTypeSummary> Types,
    IReadOnlyList<CSharpMethodSummary> Methods,
    IReadOnlyList<CSharpExportSummary> Exports,
    IReadOnlyList<CSharpParseErrorSummary> ParseErrors,
    string SemanticRuntime);

internal static class CsPluginPatchTool
{
    public static Task<BridgeToolCallResponse> ExecuteAsync(JsonElement arguments, CancellationToken cancellationToken)
    {
        try
        {
            cancellationToken.ThrowIfCancellationRequested();
            var rawPath = BridgeArgumentReader.GetRequiredString(arguments, "path");
            var path = WorkspacePathResolver.ResolveExistingPath(rawPath);
            if (!path.EndsWith(".cs", StringComparison.OrdinalIgnoreCase))
            {
                throw new BridgeToolException("cs_plugin_patch requires a .cs path.");
            }

            var dryRun = !GetOptionalBool(arguments, "dryRun", out var dryRunValue) || dryRunValue;
            var sourceText = File.ReadAllText(path);
            var readModel = PluginRoslynSyntaxCore.Read(path, sourceText);
            var action = GetRequiredString(arguments, "action");
            var typeName = ResolveTypeName(arguments, readModel, path);
            var memberName = GetOptionalString(arguments, "member_name") ?? GetOptionalString(arguments, "name");
            var signatureHint = GetOptionalString(arguments, "signature_hint");

            RuntimePatchOperationResult operation;
            var updatedText = action switch
            {
                "upsert_method" or "add_method" => PluginRoslynSyntaxCore.UpsertMethod(sourceText, BuildMethodPatch(arguments, action, typeName, memberName), out operation),
                "upsert_field" or "add_field" => PluginRoslynSyntaxCore.UpsertField(sourceText, BuildFieldPatch(arguments, action, typeName, memberName), out operation),
                "replace_method_body" => PluginRoslynSyntaxCore.ReplaceMethodBody(
                    sourceText,
                    typeName,
                    RequireMemberName(memberName, action),
                    GetStringArray(arguments, "parameters", "params"),
                    signatureHint,
                    GetOptionalString(arguments, "body"),
                    out operation),
                "delete_member" => DeleteMember(sourceText, typeName, arguments, RequireMemberName(memberName, action), signatureHint, out operation),
                "rename_member" => RenameMember(sourceText, typeName, arguments, RequireMemberName(memberName, action), signatureHint, out operation),
                _ => throw new BridgeToolException($"Unsupported Roslyn patch action: {action}"),
            };

            if (!dryRun)
            {
                WriteToolHelpers.WriteUtf8NoBom(path, updatedText);
            }
            var updatedReadModel = CSharpFileReader.ReadSource(path, updatedText);
            var result = new PluginPatchResult(
                Path: Path.GetFullPath(path),
                SourceHash: WriteToolHelpers.ComputeSha256(updatedText),
                DryRun: dryRun,
                Written: !dryRun,
                Action: action,
                TypeName: typeName,
                MemberName: RequireMemberName(memberName, action),
                Operation: ConvertOperation(operation),
                Types: updatedReadModel.Types,
                Methods: updatedReadModel.Methods,
                Exports: updatedReadModel.Exports,
                ParseErrors: updatedReadModel.ParseErrors,
                SemanticRuntime: "Roslyn");

            return Task.FromResult(BridgeToolCallResponse.Success(result));
        }
        catch (BridgeToolException ex)
        {
            return Task.FromResult(BridgeToolCallResponse.Error(ex.Message, new { error = ex.Message }));
        }
        catch (RuntimeBridgeException ex)
        {
            return Task.FromResult(BridgeToolCallResponse.Error(ex.Message, new { error = ex.Message }));
        }
        catch (Exception ex)
        {
            return Task.FromResult(BridgeToolCallResponse.Error($"cs_plugin_patch failed: {ex.Message}", new { error = ex.Message, exception = ex.GetType().Name }));
        }
    }

    private static PluginRoslynMemberPatch BuildMethodPatch(JsonElement arguments, string action, string typeName, string? memberName)
    {
        var modifiers = GetStringArray(arguments, "modifiers");
        var access = GetOptionalString(arguments, "access");
        if (string.IsNullOrWhiteSpace(access) && modifiers.Count == 0)
        {
            access = "public";
        }

        var resolvedModifiers = new List<string>();
        if (!string.IsNullOrWhiteSpace(access))
        {
            resolvedModifiers.Add(access.Trim());
        }
        resolvedModifiers.AddRange(modifiers);

        return new PluginRoslynMemberPatch(
            TypeName: typeName,
            MemberName: RequireMemberName(memberName, action),
            Modifiers: resolvedModifiers,
            ReturnType: GetOptionalString(arguments, "return_type") ?? GetOptionalString(arguments, "returnType") ?? "void",
            Parameters: GetStringArray(arguments, "parameters", "params"),
            Body: GetOptionalString(arguments, "body") ?? string.Empty,
            FieldType: null,
            Initializer: null,
            SignatureHint: GetOptionalString(arguments, "signature_hint"),
            Exported: false);
    }

    private static PluginRoslynMemberPatch BuildFieldPatch(JsonElement arguments, string action, string typeName, string? memberName)
    {
        var modifiers = GetStringArray(arguments, "modifiers");
        var access = GetOptionalString(arguments, "access");
        if (string.IsNullOrWhiteSpace(access) && modifiers.Count == 0)
        {
            access = "public";
        }

        var resolvedModifiers = new List<string>();
        if (!string.IsNullOrWhiteSpace(access))
        {
            resolvedModifiers.Add(access.Trim());
        }
        resolvedModifiers.AddRange(modifiers);

        return new PluginRoslynMemberPatch(
            TypeName: typeName,
            MemberName: RequireMemberName(memberName, action),
            Modifiers: resolvedModifiers,
            ReturnType: null,
            Parameters: Array.Empty<string>(),
            Body: null,
            FieldType: GetOptionalString(arguments, "field_type") ?? GetOptionalString(arguments, "type") ?? "Variant",
            Initializer: GetOptionalString(arguments, "value") ?? GetOptionalString(arguments, "initializer"),
            SignatureHint: GetOptionalString(arguments, "signature_hint"),
            Exported: GetOptionalBool(arguments, "exported") || GetOptionalBool(arguments, "export"));
    }

    private static string DeleteMember(string sourceText, string typeName, JsonElement arguments, string memberName, string? signatureHint, out RuntimePatchOperationResult operation)
    {
        return NormalizeMemberType(GetOptionalString(arguments, "member_type")) switch
        {
            "method" => PluginRoslynSyntaxCore.RemoveMethod(sourceText, typeName, memberName, GetStringArray(arguments, "parameters", "params"), signatureHint, out operation),
            "field" => PluginRoslynSyntaxCore.RemoveField(sourceText, typeName, memberName, signatureHint, out operation),
            "property" => PluginRoslynSyntaxCore.RemoveProperty(sourceText, typeName, memberName, signatureHint, out operation),
            _ => TryDeleteMemberAuto(sourceText, typeName, arguments, memberName, signatureHint, out operation),
        };
    }

    private static string RenameMember(string sourceText, string typeName, JsonElement arguments, string memberName, string? signatureHint, out RuntimePatchOperationResult operation)
    {
        var newName = GetRequiredString(arguments, "new_name");
        return NormalizeMemberType(GetOptionalString(arguments, "member_type")) switch
        {
            "method" => PluginRoslynSyntaxCore.RenameMethod(sourceText, typeName, memberName, newName, GetStringArray(arguments, "parameters", "params"), signatureHint, out operation),
            "field" => PluginRoslynSyntaxCore.RenameField(sourceText, typeName, memberName, newName, signatureHint, out operation),
            "property" => PluginRoslynSyntaxCore.RenameProperty(sourceText, typeName, memberName, newName, signatureHint, out operation),
            _ => TryRenameMemberAuto(sourceText, typeName, arguments, memberName, newName, signatureHint, out operation),
        };
    }

    private static string TryDeleteMemberAuto(string sourceText, string typeName, JsonElement arguments, string memberName, string? signatureHint, out RuntimePatchOperationResult operation)
    {
        Exception? lastError = null;
        try
        {
            return PluginRoslynSyntaxCore.RemoveMethod(sourceText, typeName, memberName, GetStringArray(arguments, "parameters", "params"), signatureHint, out operation);
        }
        catch (RuntimeBridgeException ex)
        {
            lastError = ex;
        }

        try
        {
            return PluginRoslynSyntaxCore.RemoveField(sourceText, typeName, memberName, signatureHint, out operation);
        }
        catch (RuntimeBridgeException ex)
        {
            lastError = ex;
        }

        try
        {
            return PluginRoslynSyntaxCore.RemoveProperty(sourceText, typeName, memberName, signatureHint, out operation);
        }
        catch (RuntimeBridgeException ex)
        {
            lastError = ex;
        }

        throw new BridgeToolException(lastError?.Message ?? $"Member '{memberName}' was not found in type '{typeName}'.");
    }

    private static string TryRenameMemberAuto(string sourceText, string typeName, JsonElement arguments, string memberName, string newName, string? signatureHint, out RuntimePatchOperationResult operation)
    {
        Exception? lastError = null;
        try
        {
            return PluginRoslynSyntaxCore.RenameMethod(sourceText, typeName, memberName, newName, GetStringArray(arguments, "parameters", "params"), signatureHint, out operation);
        }
        catch (RuntimeBridgeException ex)
        {
            lastError = ex;
        }

        try
        {
            return PluginRoslynSyntaxCore.RenameField(sourceText, typeName, memberName, newName, signatureHint, out operation);
        }
        catch (RuntimeBridgeException ex)
        {
            lastError = ex;
        }

        try
        {
            return PluginRoslynSyntaxCore.RenameProperty(sourceText, typeName, memberName, newName, signatureHint, out operation);
        }
        catch (RuntimeBridgeException ex)
        {
            lastError = ex;
        }

        throw new BridgeToolException(lastError?.Message ?? $"Member '{memberName}' was not found in type '{typeName}'.");
    }

    private static string ResolveTypeName(JsonElement arguments, PluginRoslynReadModel readModel, string path)
    {
        var explicitType = GetOptionalString(arguments, "type_name") ?? GetOptionalString(arguments, "class_name");
        if (!string.IsNullOrWhiteSpace(explicitType))
        {
            return explicitType.Trim();
        }

        var fileBaseName = Path.GetFileNameWithoutExtension(path);
        var preferredType = readModel.Types.FirstOrDefault(type => string.Equals(type.Name, fileBaseName, StringComparison.Ordinal));
        if (preferredType is not null)
        {
            return preferredType.Name;
        }

        var fallbackType = readModel.Types.FirstOrDefault();
        if (fallbackType is not null)
        {
            return fallbackType.Name;
        }

        if (!string.IsNullOrWhiteSpace(fileBaseName))
        {
            return fileBaseName;
        }

        throw new BridgeToolException("Unable to resolve the target C# type name.");
    }

    private static string RequireMemberName(string? memberName, string action)
    {
        if (!string.IsNullOrWhiteSpace(memberName))
        {
            return memberName.Trim();
        }

        throw new BridgeToolException($"Action '{action}' requires a member name.");
    }

    private static string NormalizeMemberType(string? memberType)
    {
        return (memberType ?? string.Empty).Trim().ToLowerInvariant() switch
        {
            "function" => "method",
            "variable" => "field",
            "" => "auto",
            var value => value,
        };
    }

    private static string GetRequiredString(JsonElement arguments, string name)
    {
        var value = GetOptionalString(arguments, name);
        if (string.IsNullOrWhiteSpace(value))
        {
            throw new BridgeToolException($"Missing required string field '{name}'.");
        }

        return value.Trim();
    }

    private static string? GetOptionalString(JsonElement arguments, string name)
    {
        if (arguments.ValueKind != JsonValueKind.Object || !arguments.TryGetProperty(name, out var property) || property.ValueKind == JsonValueKind.Null)
        {
            return null;
        }

        return property.ValueKind == JsonValueKind.String
            ? property.GetString()
            : property.ToString();
    }

    private static bool GetOptionalBool(JsonElement arguments, string name)
    {
        return GetOptionalBool(arguments, name, out var value) && value;
    }

    private static bool GetOptionalBool(JsonElement arguments, string name, out bool value)
    {
        value = false;
        if (arguments.ValueKind != JsonValueKind.Object || !arguments.TryGetProperty(name, out var property))
        {
            return false;
        }

        if (property.ValueKind == JsonValueKind.String)
        {
            return bool.TryParse(property.GetString(), out value);
        }

        if (property.ValueKind is JsonValueKind.True or JsonValueKind.False)
        {
            value = property.GetBoolean();
            return true;
        }

        return false;
    }

    private static IReadOnlyList<string> GetStringArray(JsonElement arguments, params string[] names)
    {
        foreach (var name in names)
        {
            if (arguments.ValueKind != JsonValueKind.Object || !arguments.TryGetProperty(name, out var property))
            {
                continue;
            }

            if (property.ValueKind == JsonValueKind.String)
            {
                var value = property.GetString();
                return string.IsNullOrWhiteSpace(value) ? Array.Empty<string>() : new[] { value.Trim() };
            }

            if (property.ValueKind != JsonValueKind.Array)
            {
                throw new BridgeToolException($"Field '{name}' must be a string or an array of strings.");
            }

            return property.EnumerateArray()
                .Where(item => item.ValueKind == JsonValueKind.String)
                .Select(item => item.GetString()?.Trim())
                .Where(item => !string.IsNullOrWhiteSpace(item))
                .Select(item => item!)
                .ToArray();
        }

        return Array.Empty<string>();
    }

    private static BridgePatchOperationResult ConvertOperation(RuntimePatchOperationResult operation)
    {
        return new BridgePatchOperationResult(
            operation.Kind,
            operation.Target,
            operation.MatchCount,
            operation.AppliedCount,
            operation.Note);
    }
}
