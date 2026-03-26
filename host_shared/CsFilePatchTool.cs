using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Xml;
using System.Xml.Linq;

namespace GodotDotnetMcp.HostShared;

internal static class CsFilePatchTool
{
    public static Task<BridgeToolCallResponse> ExecuteAsync(JsonElement arguments, CancellationToken cancellationToken)
    {
        try
        {
            var path = WorkspacePathResolver.ResolveExistingPath(BridgeArgumentReader.GetRequiredString(arguments, "path"));
            if (!path.EndsWith(".cs", StringComparison.OrdinalIgnoreCase))
            {
                throw new BridgeToolException("cs_file_patch requires a .cs path.");
            }

            var dryRun = !TryGetBoolean(arguments, "dryRun", out var dryRunValue) || dryRunValue;
            var text = File.ReadAllText(path);
            var originalLength = text.Length;
            var warnings = new List<string>();
            var operations = new List<PatchOperationResult>();

            if (!TryGetArray(arguments, "patches", out var patchesElement))
            {
                throw new BridgeToolException("cs_file_patch requires a patches array.");
            }

            foreach (var patchElement in patchesElement.EnumerateArray())
            {
                text = ApplyPatch(text, patchElement, operations, warnings);
            }

            var result = new CsFilePatchResult(
                Path: Path.GetFullPath(path),
                DryRun: dryRun,
                Written: !dryRun,
                Operations: operations,
                Warnings: warnings,
                Preview: WriteToolHelpers.PreviewText(text),
                ContentHash: WriteToolHelpers.ComputeSha256(text),
                OriginalLength: originalLength,
                NewLength: text.Length);

            if (!dryRun)
            {
                File.WriteAllText(path, text, new UTF8Encoding(encoderShouldEmitUTF8Identifier: false));
            }

            return Task.FromResult(BridgeToolCallResponse.Success(result));
        }
        catch (BridgeToolException ex)
        {
            return Task.FromResult(BridgeToolCallResponse.Error(ex.Message, new { error = ex.Message }));
        }
        catch (Exception ex)
        {
            return Task.FromResult(BridgeToolCallResponse.Error($"cs_file_patch failed: {ex.Message}", new { error = ex.Message, exception = ex.GetType().Name }));
        }
    }

    private static string ApplyPatch(string text, JsonElement patchElement, ICollection<PatchOperationResult> operations, ICollection<string> warnings)
    {
        var kind = ReadRequiredString(patchElement, "kind").ToLowerInvariant();
        var occurrence = ReadOptionalString(patchElement, "occurrence")?.ToLowerInvariant() ?? "first";
        var expectedCount = TryGetInt(patchElement, "expectedCount", out var expectedValue) ? (int?)expectedValue : null;

        switch (kind)
        {
            case "replace":
            {
                var find = ReadRequiredString(patchElement, "find");
                var replacement = ReadRequiredString(patchElement, "replacement");
                var (updated, matchCount, appliedCount, note) = ReplaceText(text, find, replacement, occurrence, expectedCount);
                operations.Add(new PatchOperationResult(kind, find, matchCount, appliedCount, note));
                return updated;
            }
            case "remove":
            {
                var find = ReadRequiredString(patchElement, "find");
                var (updated, matchCount, appliedCount, note) = RemoveText(text, find, occurrence, expectedCount);
                operations.Add(new PatchOperationResult(kind, find, matchCount, appliedCount, note));
                return updated;
            }
            case "insert_before":
            case "insert_after":
            {
                var anchor = ReadRequiredString(patchElement, "anchor");
                var insertText = ReadRequiredString(patchElement, "text");
                var (updated, matchCount, appliedCount, note) = InsertText(text, anchor, insertText, kind == "insert_before", occurrence, expectedCount);
                operations.Add(new PatchOperationResult(kind, anchor, matchCount, appliedCount, note));
                return updated;
            }
            case "method_upsert":
            {
                var patch = ParseSemanticPatch(patchElement);
                var updated = SemanticCSharpEditor.UpsertMethod(text, patch, out var operation);
                ValidateExpectedCount("method_upsert", $"{patch.TypeName}.{patch.MemberName}", operation.MatchCount, expectedCount);
                operations.Add(operation);
                return updated;
            }
            case "method_remove":
            {
                var patch = ParseSemanticPatch(patchElement);
                var updated = SemanticCSharpEditor.RemoveMethod(text, patch.TypeName, patch.MemberName, patch.Parameters, patch.SignatureHint, out var operation);
                ValidateExpectedCount("method_remove", $"{patch.TypeName}.{patch.MemberName}", operation.MatchCount, expectedCount);
                operations.Add(operation);
                return updated;
            }
            case "field_upsert":
            {
                var patch = ParseSemanticPatch(patchElement);
                var updated = SemanticCSharpEditor.UpsertField(text, patch, out var operation);
                ValidateExpectedCount("field_upsert", $"{patch.TypeName}.{patch.MemberName}", operation.MatchCount, expectedCount);
                operations.Add(operation);
                return updated;
            }
            case "field_remove":
            {
                var patch = ParseSemanticPatch(patchElement);
                var updated = SemanticCSharpEditor.RemoveField(text, patch.TypeName, patch.MemberName, patch.SignatureHint, out var operation);
                ValidateExpectedCount("field_remove", $"{patch.TypeName}.{patch.MemberName}", operation.MatchCount, expectedCount);
                operations.Add(operation);
                return updated;
            }
            default:
                throw new BridgeToolException($"Unsupported patch kind: {kind}");
        }
    }

    private static (string Updated, int MatchCount, int AppliedCount, string? Note) ReplaceText(string text, string find, string replacement, string occurrence, int? expectedCount)
    {
        var matches = CountOccurrences(text, find);
        ValidateExpectedCount("replace", find, matches, expectedCount);

        if (matches == 0)
        {
            throw new BridgeToolException($"Replace target not found: {find}");
        }

        return occurrence switch
        {
            "all" => (text.Replace(find, replacement, StringComparison.Ordinal), matches, matches, null),
            "last" => ReplaceAt(text, find, replacement, FindLastIndex(text, find), 1, $"Replaced last occurrence of '{find}'."),
            _ => ReplaceAt(text, find, replacement, text.IndexOf(find, StringComparison.Ordinal), 1, matches > 1 ? $"Multiple matches found for '{find}'; replaced first occurrence." : null),
        };
    }

    private static (string Updated, int MatchCount, int AppliedCount, string? Note) RemoveText(string text, string find, string occurrence, int? expectedCount)
    {
        var matches = CountOccurrences(text, find);
        ValidateExpectedCount("remove", find, matches, expectedCount);

        if (matches == 0)
        {
            throw new BridgeToolException($"Remove target not found: {find}");
        }

        return occurrence switch
        {
            "all" => (text.Replace(find, string.Empty, StringComparison.Ordinal), matches, matches, null),
            "last" => ReplaceAt(text, find, string.Empty, FindLastIndex(text, find), 1, $"Removed last occurrence of '{find}'."),
            _ => ReplaceAt(text, find, string.Empty, text.IndexOf(find, StringComparison.Ordinal), 1, matches > 1 ? $"Multiple matches found for '{find}'; removed first occurrence." : null),
        };
    }

    private static (string Updated, int MatchCount, int AppliedCount, string? Note) InsertText(string text, string anchor, string insertText, bool before, string occurrence, int? expectedCount)
    {
        var matches = CountOccurrences(text, anchor);
        ValidateExpectedCount("insert", anchor, matches, expectedCount);

        if (matches == 0)
        {
            throw new BridgeToolException($"Insert anchor not found: {anchor}");
        }

        return occurrence switch
        {
            "all" => InsertAtAll(text, anchor, insertText, before),
            "last" => InsertAt(text, anchor, insertText, FindLastIndex(text, anchor), before, 1, $"Inserted {(before ? "before" : "after")} last occurrence of '{anchor}'."),
            _ => InsertAt(text, anchor, insertText, text.IndexOf(anchor, StringComparison.Ordinal), before, 1, matches > 1 ? $"Multiple matches found for '{anchor}'; inserted {(before ? "before" : "after")} first occurrence." : null),
        };
    }

    private static (string Updated, int MatchCount, int AppliedCount, string? Note) ReplaceAt(string text, string find, string replacement, int index, int appliedCount, string? note)
    {
        if (index < 0)
        {
            throw new BridgeToolException($"Text not found: {find}");
        }

        return (
            Updated: text[..index] + replacement + text[(index + find.Length)..],
            MatchCount: CountOccurrences(text, find),
            AppliedCount: appliedCount,
            Note: note);
    }

    private static (string Updated, int MatchCount, int AppliedCount, string? Note) InsertAt(string text, string anchor, string insertText, int index, bool before, int appliedCount, string? note)
    {
        if (index < 0)
        {
            throw new BridgeToolException($"Anchor not found: {anchor}");
        }

        var insertionIndex = before ? index : index + anchor.Length;
        return (
            Updated: text[..insertionIndex] + insertText + text[insertionIndex..],
            MatchCount: CountOccurrences(text, anchor),
            AppliedCount: appliedCount,
            Note: note);
    }

    private static (string Updated, int MatchCount, int AppliedCount, string? Note) InsertAtAll(string text, string anchor, string insertText, bool before)
    {
        var matchIndexes = FindAllIndexes(text, anchor).ToArray();
        if (matchIndexes.Length == 0)
        {
            throw new BridgeToolException($"Anchor not found: {anchor}");
        }

        var updated = text;
        foreach (var index in matchIndexes.Reverse())
        {
            var insertionIndex = before ? index : index + anchor.Length;
            updated = updated[..insertionIndex] + insertText + updated[insertionIndex..];
        }

        return (updated, matchIndexes.Length, matchIndexes.Length, null);
    }

    private static IEnumerable<int> FindAllIndexes(string text, string value)
    {
        var currentIndex = 0;
        while (currentIndex <= text.Length - value.Length)
        {
            var index = text.IndexOf(value, currentIndex, StringComparison.Ordinal);
            if (index < 0)
            {
                yield break;
            }

            yield return index;
            currentIndex = index + Math.Max(value.Length, 1);
        }
    }

    private static int CountOccurrences(string text, string value)
    {
        if (string.IsNullOrEmpty(value))
        {
            return 0;
        }

        var count = 0;
        var index = 0;
        while (true)
        {
            index = text.IndexOf(value, index, StringComparison.Ordinal);
            if (index < 0)
            {
                break;
            }

            count++;
            index += Math.Max(value.Length, 1);
        }

        return count;
    }

    private static int FindLastIndex(string text, string value)
    {
        return text.LastIndexOf(value, StringComparison.Ordinal);
    }

    private static void ValidateExpectedCount(string kind, string target, int actualCount, int? expectedCount)
    {
        if (expectedCount.HasValue && expectedCount.Value != actualCount)
        {
            throw new BridgeToolException($"Patch conflict for {kind} target '{target}': expected {expectedCount.Value} match(es) but found {actualCount}.");
        }
    }

    private static bool TryGetArray(JsonElement arguments, string name, out JsonElement value)
    {
        value = default;
        return arguments.ValueKind == JsonValueKind.Object &&
               arguments.TryGetProperty(name, out value) &&
               value.ValueKind == JsonValueKind.Array;
    }

    private static bool TryGetBoolean(JsonElement arguments, string name, out bool value)
    {
        value = false;
        if (arguments.ValueKind != JsonValueKind.Object || !arguments.TryGetProperty(name, out var property))
        {
            return false;
        }

        if (property.ValueKind is JsonValueKind.True or JsonValueKind.False)
        {
            value = property.GetBoolean();
            return true;
        }

        return false;
    }

    private static bool TryGetInt(JsonElement arguments, string name, out int value)
    {
        value = default;
        return arguments.ValueKind == JsonValueKind.Object &&
               arguments.TryGetProperty(name, out var property) &&
               property.ValueKind == JsonValueKind.Number &&
               property.TryGetInt32(out value);
    }

    private static string ReadRequiredString(JsonElement element, string name)
    {
        if (element.ValueKind != JsonValueKind.Object || !element.TryGetProperty(name, out var property) || property.ValueKind != JsonValueKind.String)
        {
            throw new BridgeToolException($"Missing required string field '{name}'.");
        }

        var value = property.GetString();
        if (string.IsNullOrWhiteSpace(value))
        {
            throw new BridgeToolException($"Field '{name}' cannot be empty.");
        }

        return value!;
    }

    private static string? ReadOptionalString(JsonElement element, string name)
    {
        if (element.ValueKind != JsonValueKind.Object || !element.TryGetProperty(name, out var property) || property.ValueKind != JsonValueKind.String)
        {
            return null;
        }

        var value = property.GetString();
        return string.IsNullOrWhiteSpace(value) ? null : value;
    }

    private static SemanticMemberPatch ParseSemanticPatch(JsonElement patchElement)
    {
        var typeName = ReadRequiredString(patchElement, "typeName");
        var memberName = ReadRequiredString(patchElement, "memberName");
        var modifiers = BridgeArgumentReader.GetStringArray(patchElement, "modifiers");
        var parameters = BridgeArgumentReader.GetStringArray(patchElement, "parameters");

        return new SemanticMemberPatch(
            TypeName: typeName,
            MemberName: memberName,
            Modifiers: modifiers,
            ReturnType: ReadOptionalString(patchElement, "returnType"),
            Parameters: parameters,
            Body: ReadOptionalString(patchElement, "body"),
            FieldType: ReadOptionalString(patchElement, "fieldType"),
            Initializer: ReadOptionalString(patchElement, "initializer"),
            SignatureHint: ReadOptionalString(patchElement, "signatureHint"));
    }
}
