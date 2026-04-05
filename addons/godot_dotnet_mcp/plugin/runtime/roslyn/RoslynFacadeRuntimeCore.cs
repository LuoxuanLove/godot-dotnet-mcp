using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using Godot;
using GodotDotnetMcp.PluginRuntime.Roslyn;
using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp;
using Microsoft.CodeAnalysis.CSharp.Syntax;
using GodotArray = Godot.Collections.Array;
using GodotDictionary = Godot.Collections.Dictionary;

internal static class RoslynFacadeRuntimeCore
{
    private const string EngineName = "roslyn";
    private const string ModeName = "syntax";

    public static GodotDictionary get_capabilities()
    {
        return Success(BuildCapabilities(), "Plugin-internal Roslyn facade is ready.");
    }

    public static GodotDictionary parse_file(string scriptPath, string sourceText = "")
    {
        var normalizedPath = (scriptPath ?? string.Empty).Trim();
        var sourceResult = ResolveSource(normalizedPath, sourceText ?? string.Empty);
        if (!sourceResult.Success)
        {
            return Error(sourceResult.ErrorMessage, new GodotDictionary
            {
                ["engine"] = EngineName,
                ["mode"] = ModeName,
                ["degraded"] = true,
                ["path"] = normalizedPath,
            });
        }

        var readModel = PluginRoslynSyntaxCore.Read(normalizedPath, sourceResult.SourceText);
        var payload = BuildParsePayload(normalizedPath, sourceResult.SourceText, readModel);

        return Success(payload, readModel.ParseErrors.Count > 0 ? "Syntax parsed with errors." : "Syntax parsed successfully.");
    }

    public static GodotDictionary patch_file(string scriptPath, GodotDictionary request)
    {
        var normalizedPath = (scriptPath ?? string.Empty).Trim();
        if (string.IsNullOrWhiteSpace(normalizedPath))
        {
            return PatchError(normalizedPath, string.Empty, "script_path_required", "script_path is required");
        }

        if (request is null || request.Count == 0)
        {
            return PatchError(normalizedPath, string.Empty, "patch_request_required", "patch request is required");
        }

        var sourceResult = ResolveSource(normalizedPath, string.Empty);
        if (!sourceResult.Success)
        {
            return PatchError(normalizedPath, string.Empty, "script_source_unavailable", sourceResult.ErrorMessage);
        }

        try
        {
            var currentReadModel = PluginRoslynSyntaxCore.Read(normalizedPath, sourceResult.SourceText);
            var action = ReadRequiredString(request, "action");
            var typeName = ResolveTypeName(request, currentReadModel, normalizedPath);
            var memberName = ReadOptionalString(request, "member_name");
            if (string.IsNullOrWhiteSpace(memberName))
            {
                memberName = ReadOptionalString(request, "name");
            }

            var signatureHint = ReadOptionalString(request, "signature_hint");
            PatchOperationResult operation;
            string updatedText;

            switch (action)
            {
                case "upsert_method":
                case "add_method":
                    updatedText = PluginRoslynSyntaxCore.UpsertMethod(sourceResult.SourceText, BuildMethodPatch(request, typeName, memberName), out operation);
                    break;
                case "upsert_field":
                case "add_field":
                    updatedText = PluginRoslynSyntaxCore.UpsertField(sourceResult.SourceText, BuildFieldPatch(request, typeName, memberName), out operation);
                    break;
                case "replace_method_body":
                    updatedText = PluginRoslynSyntaxCore.ReplaceMethodBody(
                        sourceResult.SourceText,
                        typeName,
                        RequireMemberName(memberName, action),
                        ReadStringArray(request, "parameters", "params"),
                        signatureHint,
                        ReadOptionalString(request, "body"),
                        out operation);
                    break;
                case "delete_member":
                    updatedText = DeleteMember(sourceResult.SourceText, typeName, request, RequireMemberName(memberName, action), signatureHint, out operation);
                    break;
                case "rename_member":
                    updatedText = RenameMember(sourceResult.SourceText, typeName, request, RequireMemberName(memberName, action), signatureHint, out operation);
                    break;
                default:
                    throw new BridgeToolException($"Unsupported Roslyn patch action: {action}");
            }

            var absolutePath = ProjectSettings.GlobalizePath(normalizedPath);
            File.WriteAllText(absolutePath, updatedText);

            var updatedReadModel = PluginRoslynSyntaxCore.Read(normalizedPath, updatedText);
            var payload = BuildParsePayload(normalizedPath, updatedText, updatedReadModel);
            payload["operation"] = BuildOperation(operation);
            payload["action"] = action;
            payload["type_name"] = typeName;
            payload["member_name"] = RequireMemberName(memberName, action);

            return Success(payload, "Syntax patch applied successfully.");
        }
        catch (BridgeToolException ex)
        {
            return PatchError(normalizedPath, sourceResult.SourceText, "roslyn_patch_failed", ex.Message);
        }
    }

    private static GodotDictionary BuildCapabilities()
    {
        return new GodotDictionary
        {
            ["engine"] = EngineName,
            ["mode"] = ModeName,
            ["transport"] = "in_process",
            ["entrypoint"] = "plugin_internal_facade",
            ["supports_unsaved_source"] = true,
            ["degraded"] = false,
        };
    }

    private static SourceResolveResult ResolveSource(string scriptPath, string sourceText)
    {
        if (!string.IsNullOrEmpty(sourceText))
        {
            return new SourceResolveResult(true, sourceText, string.Empty);
        }

        if (string.IsNullOrWhiteSpace(scriptPath))
        {
            return new SourceResolveResult(false, string.Empty, "script_path is required when source_text is empty.");
        }

        var absolutePath = ProjectSettings.GlobalizePath(scriptPath);
        if (!File.Exists(absolutePath))
        {
            return new SourceResolveResult(false, string.Empty, $"Script file not found: {scriptPath}");
        }

        return new SourceResolveResult(true, File.ReadAllText(absolutePath), string.Empty);
    }

    private static GodotDictionary BuildParseError(PluginRoslynParseError parseError)
    {
        return new GodotDictionary
        {
            ["severity"] = parseError.Severity,
            ["code"] = parseError.Code,
            ["message"] = parseError.Message,
            ["line"] = parseError.Line,
            ["column"] = parseError.Column,
        };
    }

    private static GodotArray BuildUsings(IReadOnlyList<string> usings)
    {
        var items = new GodotArray();
        foreach (var usingText in usings)
        {
            items.Add(usingText);
        }

        return items;
    }

    private static GodotArray BuildStringArray(IEnumerable<string> values)
    {
        var items = new GodotArray();
        foreach (var value in values)
        {
            items.Add(value);
        }

        return items;
    }

    private static GodotArray BuildTypes(IReadOnlyList<PluginRoslynTypeSummary> types)
    {
        var items = new GodotArray();
        foreach (var type in types)
        {
            items.Add(new GodotDictionary
            {
                ["name"] = type.Name,
                ["kind"] = type.Kind,
                ["namespace"] = type.Namespace,
                ["partial"] = type.Partial,
                ["base_type"] = type.BaseType,
                ["modifiers"] = BuildStringArray(type.Modifiers),
                ["line"] = type.Line,
                ["column"] = type.Column,
            });
        }

        return items;
    }

    private static GodotArray BuildMethods(IReadOnlyList<PluginRoslynMethodSummary> methods)
    {
        var items = new GodotArray();
        foreach (var method in methods)
        {
            items.Add(new GodotDictionary
            {
                ["name"] = method.Name,
                ["return_type"] = method.ReturnType,
                ["containing_type"] = method.ContainingType,
                ["parameters"] = BuildStringArray(method.Parameters),
                ["modifiers"] = BuildStringArray(method.Modifiers),
                ["line"] = method.Line,
                ["column"] = method.Column,
            });
        }

        return items;
    }

    private static GodotArray ExtractExports(CompilationUnitSyntax root)
    {
        var items = new GodotArray();

        foreach (var field in root.DescendantNodes().OfType<FieldDeclarationSyntax>())
        {
            if (!HasExportAttribute(field.AttributeLists))
            {
                continue;
            }

            foreach (var variable in field.Declaration.Variables)
            {
                items.Add(new GodotDictionary
                {
                    ["name"] = variable.Identifier.Text,
                    ["member_type"] = "field",
                    ["type_name"] = field.Declaration.Type.ToString(),
                });
            }
        }

        foreach (var property in root.DescendantNodes().OfType<PropertyDeclarationSyntax>())
        {
            if (!HasExportAttribute(property.AttributeLists))
            {
                continue;
            }

            items.Add(new GodotDictionary
            {
                ["name"] = property.Identifier.Text,
                ["member_type"] = "property",
                ["type_name"] = property.Type.ToString(),
            });
        }

        return items;
    }

    private static bool HasExportAttribute(SyntaxList<AttributeListSyntax> attributeLists)
    {
        foreach (var attributeList in attributeLists)
        {
            foreach (var attribute in attributeList.Attributes)
            {
                var name = attribute.Name.ToString();
                if (name == "Export" || name == "ExportAttribute" || name.EndsWith(".Export") || name.EndsWith(".ExportAttribute"))
                {
                    return true;
                }
            }
        }

        return false;
    }

    private static GodotDictionary BuildParsePayload(string normalizedPath, string sourceText, PluginRoslynReadModel readModel)
    {
        var parseErrors = new GodotArray();
        foreach (var error in readModel.ParseErrors)
        {
            parseErrors.Add(BuildParseError(error));
        }

        var payload = BuildCapabilities();
        payload["degraded"] = parseErrors.Count > 0;
        payload["path"] = normalizedPath;
        payload["source_hash"] = ComputeSourceHash(sourceText);
        payload["namespace"] = readModel.Namespace;
        payload["usings"] = BuildUsings(readModel.Usings);
        payload["parse_errors"] = parseErrors;
        payload["types"] = BuildTypes(readModel.Types);
        payload["methods"] = BuildMethods(readModel.Methods);
        payload["exports"] = ExtractExports(readModel.Root);
        return payload;
    }

    private static GodotDictionary BuildOperation(PatchOperationResult operation)
    {
        return new GodotDictionary
        {
            ["kind"] = operation.Kind,
            ["target"] = operation.Target,
            ["match_count"] = operation.MatchCount,
            ["applied_count"] = operation.AppliedCount,
            ["note"] = operation.Note ?? string.Empty,
        };
    }

    private static PluginRoslynMemberPatch BuildMethodPatch(GodotDictionary request, string typeName, string? memberName)
    {
        var resolvedMemberName = RequireMemberName(memberName, ReadRequiredString(request, "action"));
        var modifiers = ReadStringArray(request, "modifiers");
        var access = ReadOptionalString(request, "access");
        if (string.IsNullOrWhiteSpace(access) && modifiers.Count == 0)
        {
            access = "public";
        }
        if (!string.IsNullOrWhiteSpace(access))
        {
            modifiers.Insert(0, access.Trim());
        }

        return new PluginRoslynMemberPatch(
            TypeName: typeName,
            MemberName: resolvedMemberName,
            Modifiers: modifiers,
            ReturnType: ReadOptionalString(request, "return_type") ?? ReadOptionalString(request, "returnType") ?? "void",
            Parameters: ReadStringArray(request, "parameters", "params"),
            Body: ReadOptionalString(request, "body") ?? string.Empty,
            FieldType: null,
            Initializer: null,
            SignatureHint: ReadOptionalString(request, "signature_hint"),
            Exported: false);
    }

    private static PluginRoslynMemberPatch BuildFieldPatch(GodotDictionary request, string typeName, string? memberName)
    {
        var resolvedMemberName = RequireMemberName(memberName, ReadRequiredString(request, "action"));
        var modifiers = ReadStringArray(request, "modifiers");
        var access = ReadOptionalString(request, "access");
        if (string.IsNullOrWhiteSpace(access) && modifiers.Count == 0)
        {
            access = "public";
        }
        if (!string.IsNullOrWhiteSpace(access))
        {
            modifiers.Insert(0, access.Trim());
        }

        return new PluginRoslynMemberPatch(
            TypeName: typeName,
            MemberName: resolvedMemberName,
            Modifiers: modifiers,
            ReturnType: null,
            Parameters: Array.Empty<string>(),
            Body: null,
            FieldType: ReadOptionalString(request, "field_type") ?? ReadOptionalString(request, "type") ?? "Variant",
            Initializer: ReadOptionalString(request, "value") ?? ReadOptionalString(request, "initializer"),
            SignatureHint: ReadOptionalString(request, "signature_hint"),
            Exported: ReadOptionalBool(request, "exported") || ReadOptionalBool(request, "export"));
    }

    private static string DeleteMember(string sourceText, string typeName, GodotDictionary request, string memberName, string? signatureHint, out PatchOperationResult operation)
    {
        var memberType = NormalizeMemberType(ReadOptionalString(request, "member_type"));
        return memberType switch
        {
            "method" => PluginRoslynSyntaxCore.RemoveMethod(sourceText, typeName, memberName, ReadStringArray(request, "parameters", "params"), signatureHint, out operation),
            "field" => PluginRoslynSyntaxCore.RemoveField(sourceText, typeName, memberName, signatureHint, out operation),
            "property" => PluginRoslynSyntaxCore.RemoveProperty(sourceText, typeName, memberName, signatureHint, out operation),
            _ => TryDeleteMemberAuto(sourceText, typeName, request, memberName, signatureHint, out operation),
        };
    }

    private static string RenameMember(string sourceText, string typeName, GodotDictionary request, string memberName, string? signatureHint, out PatchOperationResult operation)
    {
        var newName = ReadRequiredString(request, "new_name");
        var memberType = NormalizeMemberType(ReadOptionalString(request, "member_type"));
        return memberType switch
        {
            "method" => PluginRoslynSyntaxCore.RenameMethod(sourceText, typeName, memberName, newName, ReadStringArray(request, "parameters", "params"), signatureHint, out operation),
            "field" => PluginRoslynSyntaxCore.RenameField(sourceText, typeName, memberName, newName, signatureHint, out operation),
            "property" => PluginRoslynSyntaxCore.RenameProperty(sourceText, typeName, memberName, newName, signatureHint, out operation),
            _ => TryRenameMemberAuto(sourceText, typeName, request, memberName, newName, signatureHint, out operation),
        };
    }

    private static string TryDeleteMemberAuto(string sourceText, string typeName, GodotDictionary request, string memberName, string? signatureHint, out PatchOperationResult operation)
    {
        BridgeToolException? lastError = null;
        try
        {
            return PluginRoslynSyntaxCore.RemoveMethod(sourceText, typeName, memberName, ReadStringArray(request, "parameters", "params"), signatureHint, out operation);
        }
        catch (BridgeToolException ex)
        {
            lastError = ex;
        }

        try
        {
            return PluginRoslynSyntaxCore.RemoveField(sourceText, typeName, memberName, signatureHint, out operation);
        }
        catch (BridgeToolException ex)
        {
            lastError = ex;
        }

        try
        {
            return PluginRoslynSyntaxCore.RemoveProperty(sourceText, typeName, memberName, signatureHint, out operation);
        }
        catch (BridgeToolException ex)
        {
            lastError = ex;
        }

        throw lastError ?? new BridgeToolException($"Member '{memberName}' was not found in type '{typeName}'.");
    }

    private static string TryRenameMemberAuto(string sourceText, string typeName, GodotDictionary request, string memberName, string newName, string? signatureHint, out PatchOperationResult operation)
    {
        BridgeToolException? lastError = null;
        try
        {
            return PluginRoslynSyntaxCore.RenameMethod(sourceText, typeName, memberName, newName, ReadStringArray(request, "parameters", "params"), signatureHint, out operation);
        }
        catch (BridgeToolException ex)
        {
            lastError = ex;
        }

        try
        {
            return PluginRoslynSyntaxCore.RenameField(sourceText, typeName, memberName, newName, signatureHint, out operation);
        }
        catch (BridgeToolException ex)
        {
            lastError = ex;
        }

        try
        {
            return PluginRoslynSyntaxCore.RenameProperty(sourceText, typeName, memberName, newName, signatureHint, out operation);
        }
        catch (BridgeToolException ex)
        {
            lastError = ex;
        }

        throw lastError ?? new BridgeToolException($"Member '{memberName}' was not found in type '{typeName}'.");
    }

    private static string ResolveTypeName(GodotDictionary request, PluginRoslynReadModel readModel, string normalizedPath)
    {
        var explicitType = ReadOptionalString(request, "type_name") ?? ReadOptionalString(request, "class_name");
        if (!string.IsNullOrWhiteSpace(explicitType))
        {
            return explicitType.Trim();
        }

        var fileBaseName = Path.GetFileNameWithoutExtension(normalizedPath);
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

    private static string ReadRequiredString(GodotDictionary request, string key)
    {
        var value = ReadOptionalString(request, key);
        if (!string.IsNullOrWhiteSpace(value))
        {
            return value.Trim();
        }

        throw new BridgeToolException($"Missing required string field '{key}'.");
    }

    private static string? ReadOptionalString(GodotDictionary request, string key)
    {
        if (!request.ContainsKey(key))
        {
            return null;
        }

        Variant raw = request[key];
        if (raw.VariantType == Variant.Type.Nil)
        {
            return null;
        }

        var value = raw.ToString();
        return string.IsNullOrWhiteSpace(value) ? null : value;
    }

    private static bool ReadOptionalBool(GodotDictionary request, string key)
    {
        if (!request.ContainsKey(key))
        {
            return false;
        }

        Variant raw = request[key];
        if (raw.VariantType == Variant.Type.Bool)
        {
            return raw.AsBool();
        }

        if (raw.VariantType == Variant.Type.String && bool.TryParse(raw.AsString(), out var parsed))
        {
            return parsed;
        }

        return false;
    }

    private static List<string> ReadStringArray(GodotDictionary request, params string[] keys)
    {
        foreach (var key in keys)
        {
            if (!request.ContainsKey(key))
            {
                continue;
            }

            Variant raw = request[key];
            if (raw.VariantType == Variant.Type.Array)
            {
                var godotArray = raw.AsGodotArray();
                return godotArray.Cast<object?>()
                    .Select(item => item?.ToString()?.Trim())
                    .Where(item => !string.IsNullOrWhiteSpace(item))
                    .Select(item => item!)
                    .ToList();
            }

            if (raw.VariantType == Variant.Type.String)
            {
                var stringValue = raw.AsString();
                if (string.IsNullOrWhiteSpace(stringValue))
                {
                    continue;
                }

                return new List<string> { stringValue.Trim() };
            }
        }

        return new List<string>();
    }

    private static GodotDictionary PatchError(string normalizedPath, string sourceText, string errorCode, string message)
    {
        var data = BuildCapabilities();
        data["degraded"] = true;
        data["path"] = normalizedPath;
        data["source_hash"] = string.IsNullOrEmpty(sourceText) ? string.Empty : ComputeSourceHash(sourceText);
        data["error_type"] = "roslyn_failure";
        data["error_code"] = errorCode;
        data["types"] = new GodotArray();
        data["methods"] = new GodotArray();
        data["exports"] = new GodotArray();
        data["parse_errors"] = new GodotArray();
        return Error(message, data);
    }

    private static string ComputeSourceHash(string sourceText)
    {
        var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(sourceText));
        var builder = new StringBuilder(bytes.Length * 2);
        foreach (var item in bytes)
        {
            builder.Append(item.ToString("x2"));
        }

        return builder.ToString();
    }

    private static GodotDictionary Success(GodotDictionary data, string message)
    {
        return new GodotDictionary
        {
            ["success"] = true,
            ["data"] = data,
            ["message"] = message,
        };
    }

    private static GodotDictionary Error(string message, GodotDictionary data)
    {
        return new GodotDictionary
        {
            ["success"] = false,
            ["error"] = message,
            ["data"] = data,
        };
    }

    private readonly record struct SourceResolveResult(bool Success, string SourceText, string ErrorMessage);
}
