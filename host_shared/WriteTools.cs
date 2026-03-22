using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Xml;
using System.Xml.Linq;

namespace GodotDotnetMcp.HostShared;

internal sealed record CsprojWriteResult(
    string Path,
    bool DryRun,
    bool Written,
    IReadOnlyList<string> Changes,
    IReadOnlyList<string> Warnings,
    string Preview,
    string ContentHash,
    string? TargetFramework,
    IReadOnlyList<string> TargetFrameworks,
    IReadOnlyList<CsprojReferenceInfo> PackageReferences,
    IReadOnlyList<CsprojReferenceInfo> ProjectReferences);

internal sealed record CsFilePatchResult(
    string Path,
    bool DryRun,
    bool Written,
    IReadOnlyList<PatchOperationResult> Operations,
    IReadOnlyList<string> Warnings,
    string Preview,
    string ContentHash,
    int OriginalLength,
    int NewLength);

internal sealed record PatchOperationResult(
    string Kind,
    string Target,
    int MatchCount,
    int AppliedCount,
    string? Note);

internal static class CsprojWriteTool
{
    public static Task<BridgeToolCallResponse> ExecuteAsync(JsonElement arguments, CancellationToken cancellationToken)
    {
        try
        {
            var path = WorkspacePathResolver.ResolveExistingPath(BridgeArgumentReader.GetRequiredString(arguments, "path"));
            if (!path.EndsWith(".csproj", StringComparison.OrdinalIgnoreCase))
            {
                throw new BridgeToolException("csproj_write requires a .csproj path.");
            }

            var dryRun = !TryGetBoolean(arguments, "dryRun", out var dryRunValue) || dryRunValue;
            var document = XDocument.Load(path, LoadOptions.PreserveWhitespace);
            var root = document.Root ?? throw new BridgeToolException("Project file has no root element.");
            var ns = root.Name.Namespace;

            var changes = new List<string>();
            var warnings = new List<string>();

            if (TryGetObject(arguments, "properties", out var propertiesElement))
            {
                foreach (var property in propertiesElement.EnumerateObject())
                {
                    if (property.Value.ValueKind != JsonValueKind.String)
                    {
                        throw new BridgeToolException($"Property '{property.Name}' must be a string.");
                    }

                    var value = property.Value.GetString() ?? string.Empty;
                    UpsertProjectProperty(root, ns, property.Name, value, changes);
                }
            }

            if (TryGetString(arguments, "targetFramework", out var targetFrameworkValue))
            {
                SetTargetFramework(root, ns, targetFrameworkValue!, changes);
            }

            if (TryGetArrayOfStrings(arguments, "targetFrameworks", out var targetFrameworks))
            {
                SetTargetFrameworks(root, ns, targetFrameworks, changes);
            }

            if (TryGetArrayOfStrings(arguments, "removeProperties", out var removeProperties))
            {
                foreach (var propertyName in removeProperties)
                {
                    if (RemoveProjectProperty(root, ns, propertyName))
                    {
                        changes.Add($"Removed project property '{propertyName}'.");
                    }
                    else
                    {
                        warnings.Add($"Project property '{propertyName}' was not found.");
                    }
                }
            }

            if (TryGetObject(arguments, "packageReferences", out var packageReferencesElement))
            {
                ApplyPackageReferenceChanges(root, ns, packageReferencesElement, changes, warnings);
            }

            if (TryGetObject(arguments, "projectReferences", out var projectReferencesElement))
            {
                ApplyProjectReferenceChanges(root, ns, projectReferencesElement, changes, warnings);
            }

            var preview = RenderDocument(document);
            var result = new CsprojWriteResult(
                Path: Path.GetFullPath(path),
                DryRun: dryRun,
                Written: !dryRun,
                Changes: changes,
                Warnings: warnings,
                Preview: WriteToolHelpers.PreviewText(preview),
                ContentHash: WriteToolHelpers.ComputeSha256(preview),
                TargetFramework: ReadTargetFramework(root, ns),
                TargetFrameworks: ReadTargetFrameworks(root, ns),
                PackageReferences: ReadPackageReferences(root, ns),
                ProjectReferences: ReadProjectReferences(root, ns));

            if (!dryRun)
            {
                File.WriteAllText(path, preview, new UTF8Encoding(encoderShouldEmitUTF8Identifier: false));
            }

            return Task.FromResult(BridgeToolCallResponse.Success(result));
        }
        catch (BridgeToolException ex)
        {
            return Task.FromResult(BridgeToolCallResponse.Error(ex.Message, new { error = ex.Message }));
        }
        catch (Exception ex)
        {
            return Task.FromResult(BridgeToolCallResponse.Error($"csproj_write failed: {ex.Message}", new { error = ex.Message, exception = ex.GetType().Name }));
        }
    }

    private static void ApplyPackageReferenceChanges(XElement root, XNamespace ns, JsonElement packageReferencesElement, ICollection<string> changes, ICollection<string> warnings)
    {
        if (packageReferencesElement.TryGetProperty("add", out var addElement))
        {
            ApplyReferenceGroup(root, ns, addElement, "PackageReference", changes, warnings, allowCreate: true, requireExisting: false);
        }

        if (packageReferencesElement.TryGetProperty("update", out var updateElement))
        {
            ApplyReferenceGroup(root, ns, updateElement, "PackageReference", changes, warnings, allowCreate: false, requireExisting: true);
        }

        if (packageReferencesElement.TryGetProperty("remove", out var removeElement))
        {
            foreach (var include in ReadStringArray(removeElement, "packageReferences.remove"))
            {
                var removed = RemoveReferences(root, ns, "PackageReference", include);
                if (removed > 0)
                {
                    changes.Add($"Removed PackageReference '{include}' ({removed} matches).");
                }
                else
                {
                    warnings.Add($"PackageReference '{include}' was not found.");
                }
            }
        }
    }

    private static void ApplyProjectReferenceChanges(XElement root, XNamespace ns, JsonElement projectReferencesElement, ICollection<string> changes, ICollection<string> warnings)
    {
        if (projectReferencesElement.TryGetProperty("add", out var addElement))
        {
            ApplyReferenceGroup(root, ns, addElement, "ProjectReference", changes, warnings, allowCreate: true, requireExisting: false);
        }

        if (projectReferencesElement.TryGetProperty("update", out var updateElement))
        {
            ApplyReferenceGroup(root, ns, updateElement, "ProjectReference", changes, warnings, allowCreate: false, requireExisting: true);
        }

        if (projectReferencesElement.TryGetProperty("remove", out var removeElement))
        {
            foreach (var include in ReadStringArray(removeElement, "projectReferences.remove"))
            {
                var removed = RemoveReferences(root, ns, "ProjectReference", include);
                if (removed > 0)
                {
                    changes.Add($"Removed ProjectReference '{include}' ({removed} matches).");
                }
                else
                {
                    warnings.Add($"ProjectReference '{include}' was not found.");
                }
            }
        }
    }

    private static void ApplyReferenceGroup(XElement root, XNamespace ns, JsonElement arrayElement, string elementName, ICollection<string> changes, ICollection<string> warnings, bool allowCreate, bool requireExisting)
    {
        if (arrayElement.ValueKind != JsonValueKind.Array)
        {
            throw new BridgeToolException($"{elementName} changes must be arrays.");
        }

        foreach (var item in arrayElement.EnumerateArray())
        {
            var include = ReadRequiredString(item, "include");
            var version = ReadOptionalString(item, "version");
            var condition = ReadOptionalString(item, "condition");
            var metadata = TryGetObject(item, "metadata", out var metadataElement)
                ? ReadStringDictionary(metadataElement, "metadata")
                : new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);

            var existing = FindReference(root, ns, elementName, include);
            if (existing is null)
            {
                if (requireExisting)
                {
                    warnings.Add($"{elementName} '{include}' was not found.");
                    continue;
                }

                if (!allowCreate)
                {
                    warnings.Add($"{elementName} '{include}' was not found.");
                    continue;
                }

                var itemGroup = EnsureItemGroup(root, ns);
                existing = new XElement(ns + elementName, new XAttribute("Include", include));
                itemGroup.Add(existing);
                changes.Add($"Added {elementName} '{include}'.");
            }
            else
            {
                changes.Add($"Updated {elementName} '{include}'.");
            }

            if (!string.IsNullOrWhiteSpace(version))
            {
                SetPackageReferenceVersion(existing, version!);
            }

            SetReferenceAttribute(existing, "Condition", condition);
            SetReferenceMetadata(existing, metadata, changes, $"{elementName} '{include}'");
        }
    }

    private static XElement EnsureItemGroup(XElement root, XNamespace ns)
    {
        var itemGroup = root.Elements(ns + "ItemGroup").FirstOrDefault(element => element.Attribute("Condition") is null);
        if (itemGroup is not null)
        {
            return itemGroup;
        }

        itemGroup = new XElement(ns + "ItemGroup");
        root.Add(itemGroup);
        return itemGroup;
    }

    private static void UpsertProjectProperty(XElement root, XNamespace ns, string name, string value, ICollection<string> changes)
    {
        var propertyGroup = root.Elements(ns + "PropertyGroup").FirstOrDefault(element => element.Attribute("Condition") is null);
        if (propertyGroup is null)
        {
            propertyGroup = new XElement(ns + "PropertyGroup");
            root.Add(propertyGroup);
        }

        var propertyElement = propertyGroup.Elements(ns + name).FirstOrDefault();
        if (propertyElement is null)
        {
            propertyGroup.Add(new XElement(ns + name, value));
            changes.Add($"Added project property '{name}' = '{value}'.");
            return;
        }

        propertyElement.Value = value;
        changes.Add($"Updated project property '{name}' = '{value}'.");
    }

    private static bool RemoveProjectProperty(XElement root, XNamespace ns, string name)
    {
        var removed = false;
        foreach (var propertyElement in root.Descendants(ns + name).ToArray())
        {
            propertyElement.Remove();
            removed = true;
        }

        return removed;
    }

    private static XElement? FindReference(XElement root, XNamespace ns, string elementName, string include)
    {
        return root.Descendants(ns + elementName)
            .FirstOrDefault(element =>
                string.Equals(ReadAttribute(element, "Include") ?? ReadAttribute(element, "Update"), include, StringComparison.OrdinalIgnoreCase));
    }

    private static int RemoveReferences(XElement root, XNamespace ns, string elementName, string include)
    {
        var removed = 0;
        foreach (var element in root.Descendants(ns + elementName).ToArray())
        {
            var existingInclude = ReadAttribute(element, "Include") ?? ReadAttribute(element, "Update");
            if (!string.Equals(existingInclude, include, StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }

            element.Remove();
            removed++;
        }

        return removed;
    }

    private static void SetPackageReferenceVersion(XElement element, string version)
    {
        var versionElement = element.Elements().FirstOrDefault(child => child.Name.LocalName == "Version");
        if (versionElement is not null)
        {
            versionElement.Value = version;
            return;
        }

        element.SetAttributeValue("Version", version);
    }

    private static void SetReferenceAttribute(XElement element, string name, string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            element.Attribute(name)?.Remove();
            return;
        }

        element.SetAttributeValue(name, value);
    }

    private static void SetReferenceMetadata(XElement element, IReadOnlyDictionary<string, string> metadata, ICollection<string> changes, string target)
    {
        foreach (var (key, value) in metadata)
        {
            var metadataElement = element.Elements().FirstOrDefault(child => child.Name.LocalName.Equals(key, StringComparison.OrdinalIgnoreCase));
            if (metadataElement is null)
            {
                element.Add(new XElement(element.Name.Namespace + key, value));
                continue;
            }

            metadataElement.Value = value;
        }

        if (metadata.Count > 0)
        {
            changes.Add($"Updated metadata for {target}.");
        }
    }

    private static void SetTargetFramework(XElement root, XNamespace ns, string value, ICollection<string> changes)
    {
        var propertyGroup = EnsurePropertyGroup(root, ns);
        SetProjectProperty(propertyGroup, ns, "TargetFramework", value);
        RemoveProjectProperty(root, ns, "TargetFrameworks");
        changes.Add($"Set TargetFramework = '{value}'.");
    }

    private static void SetTargetFrameworks(XElement root, XNamespace ns, IReadOnlyList<string> values, ICollection<string> changes)
    {
        if (values.Count == 0)
        {
            throw new BridgeToolException("targetFrameworks cannot be empty.");
        }

        var propertyGroup = EnsurePropertyGroup(root, ns);
        SetProjectProperty(propertyGroup, ns, "TargetFrameworks", string.Join(';', values));
        RemoveProjectProperty(root, ns, "TargetFramework");
        changes.Add($"Set TargetFrameworks = '{string.Join(';', values)}'.");
    }

    private static string? ReadTargetFramework(XElement root, XNamespace ns)
    {
        return root.Descendants(ns + "TargetFramework").Select(element => element.Value.Trim()).FirstOrDefault(value => !string.IsNullOrWhiteSpace(value));
    }

    private static IReadOnlyList<string> ReadTargetFrameworks(XElement root, XNamespace ns)
    {
        var targetFrameworks = root.Descendants(ns + "TargetFrameworks")
            .Select(element => element.Value.Trim())
            .FirstOrDefault(value => !string.IsNullOrWhiteSpace(value));

        if (string.IsNullOrWhiteSpace(targetFrameworks))
        {
            var targetFramework = ReadTargetFramework(root, ns);
            return string.IsNullOrWhiteSpace(targetFramework)
                ? Array.Empty<string>()
                : [targetFramework];
        }

        return targetFrameworks.Split(';', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
    }

    private static IReadOnlyList<CsprojReferenceInfo> ReadPackageReferences(XElement root, XNamespace ns)
    {
        return root.Descendants(ns + "PackageReference")
            .Select(element => new CsprojReferenceInfo(
                ReadAttribute(element, "Include") ?? ReadAttribute(element, "Update") ?? string.Empty,
                element.Attribute("Condition")?.Value,
                ReadMetadata(element)))
            .Where(reference => !string.IsNullOrWhiteSpace(reference.Include))
            .ToArray();
    }

    private static IReadOnlyList<CsprojReferenceInfo> ReadProjectReferences(XElement root, XNamespace ns)
    {
        return root.Descendants(ns + "ProjectReference")
            .Select(element => new CsprojReferenceInfo(
                ReadAttribute(element, "Include") ?? string.Empty,
                element.Attribute("Condition")?.Value,
                ReadMetadata(element)))
            .Where(reference => !string.IsNullOrWhiteSpace(reference.Include))
            .ToArray();
    }

    private static IReadOnlyDictionary<string, string> ReadMetadata(XElement element)
    {
        return element.Elements()
            .Where(child => !child.HasElements)
            .ToDictionary(child => child.Name.LocalName, child => child.Value.Trim(), StringComparer.OrdinalIgnoreCase);
    }

    private static XElement EnsurePropertyGroup(XElement root, XNamespace ns)
    {
        var propertyGroup = root.Elements(ns + "PropertyGroup").FirstOrDefault(element => element.Attribute("Condition") is null);
        if (propertyGroup is not null)
        {
            return propertyGroup;
        }

        propertyGroup = new XElement(ns + "PropertyGroup");
        root.Add(propertyGroup);
        return propertyGroup;
    }

    private static void SetProjectProperty(XElement propertyGroup, XNamespace ns, string name, string value)
    {
        var propertyElement = propertyGroup.Elements(ns + name).FirstOrDefault();
        if (propertyElement is null)
        {
            propertyGroup.Add(new XElement(ns + name, value));
            return;
        }

        propertyElement.Value = value;
    }

    private static string? ReadAttribute(XElement element, string name)
    {
        return element.Attribute(name)?.Value;
    }

    private static bool TryGetObject(JsonElement arguments, string name, out JsonElement value)
    {
        value = default;
        return arguments.ValueKind == JsonValueKind.Object &&
               arguments.TryGetProperty(name, out value) &&
               value.ValueKind == JsonValueKind.Object;
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

    private static bool TryGetArrayOfStrings(JsonElement arguments, string name, out IReadOnlyList<string> values)
    {
        values = Array.Empty<string>();
        if (arguments.ValueKind != JsonValueKind.Object || !arguments.TryGetProperty(name, out var property) || property.ValueKind != JsonValueKind.Array)
        {
            return false;
        }

        values = ReadStringArray(property, name);
        return true;
    }

    private static bool TryGetString(JsonElement arguments, string name, out string? value)
    {
        value = null;
        return arguments.ValueKind == JsonValueKind.Object &&
               arguments.TryGetProperty(name, out var property) &&
               property.ValueKind == JsonValueKind.String &&
               (value = property.GetString()) is not null &&
               !string.IsNullOrWhiteSpace(value);
    }

    private static IReadOnlyList<string> ReadStringArray(JsonElement property, string argumentName)
    {
        if (property.ValueKind != JsonValueKind.Array)
        {
            throw new BridgeToolException($"Argument '{argumentName}' must be an array of strings.");
        }

        var values = new List<string>();
        foreach (var item in property.EnumerateArray())
        {
            if (item.ValueKind != JsonValueKind.String)
            {
                throw new BridgeToolException($"Argument '{argumentName}' must only contain strings.");
            }

            values.Add(item.GetString() ?? string.Empty);
        }

        return values;
    }

    private static IReadOnlyDictionary<string, string> ReadStringDictionary(JsonElement property, string argumentName)
    {
        if (property.ValueKind != JsonValueKind.Object)
        {
            throw new BridgeToolException($"Argument '{argumentName}' must be an object of strings.");
        }

        var values = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        foreach (var item in property.EnumerateObject())
        {
            if (item.Value.ValueKind != JsonValueKind.String)
            {
                throw new BridgeToolException($"Argument '{argumentName}' must only contain string values.");
            }

            values[item.Name] = item.Value.GetString() ?? string.Empty;
        }

        return values;
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

    private static string RenderDocument(XDocument document)
    {
        RemoveWhitespaceNodes(document);
        var settings = new XmlWriterSettings
        {
            Encoding = new UTF8Encoding(encoderShouldEmitUTF8Identifier: false),
            Indent = true,
            IndentChars = "  ",
            NewLineHandling = NewLineHandling.Replace,
            OmitXmlDeclaration = false,
            NewLineChars = Environment.NewLine,
        };

        using var stream = new MemoryStream();
        using (var writer = XmlWriter.Create(stream, settings))
        {
            document.Save(writer);
        }

        return Encoding.UTF8.GetString(stream.ToArray());
    }

    private static void RemoveWhitespaceNodes(XContainer container)
    {
        foreach (var node in container.Nodes().ToArray())
        {
            switch (node)
            {
                case XText text when string.IsNullOrWhiteSpace(text.Value):
                    text.Remove();
                    break;
                case XElement element:
                    RemoveWhitespaceNodes(element);
                    break;
            }
        }
    }
}

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

internal static class WriteToolHelpers
{
    public static string PreviewText(string text, int maxChars = 4_000)
    {
        return text.Length <= maxChars ? text : text[..maxChars] + Environment.NewLine + "...[truncated]";
    }

    public static string ComputeSha256(string text)
    {
        var bytes = Encoding.UTF8.GetBytes(text);
        var hash = SHA256.HashData(bytes);
        return Convert.ToHexString(hash).ToLowerInvariant();
    }
}
