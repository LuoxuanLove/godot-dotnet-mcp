using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Xml;
using System.Xml.Linq;

namespace GodotDotnetMcp.HostShared;

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
