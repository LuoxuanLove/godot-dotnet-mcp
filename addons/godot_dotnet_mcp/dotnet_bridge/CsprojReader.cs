using System.Xml.Linq;

namespace GodotDotnetMcp.DotnetBridge;

internal sealed record CsprojPropertyGroupInfo(string? Condition, IReadOnlyDictionary<string, string> Properties);

internal sealed record CsprojReferenceInfo(string Include, string? Condition, IReadOnlyDictionary<string, string> Metadata);

internal sealed record CsprojReadModel(
    string Path,
    bool IsSdkStyle,
    string? Sdk,
    IReadOnlyList<string> TargetFrameworks,
    string? TargetFramework,
    IReadOnlyDictionary<string, string> EffectiveProperties,
    IReadOnlyList<CsprojPropertyGroupInfo> PropertyGroups,
    IReadOnlyList<CsprojReferenceInfo> PackageReferences,
    IReadOnlyList<CsprojReferenceInfo> ProjectReferences);

internal static class CsprojReader
{
    public static CsprojReadModel Read(string path)
    {
        var document = XDocument.Load(path);
        var root = document.Root ?? throw new InvalidDataException("Project file has no root element.");
        var sdk = root.Attribute("Sdk")?.Value;
        var isSdkStyle = !string.IsNullOrWhiteSpace(sdk);
        var propertyGroups = new List<CsprojPropertyGroupInfo>();
        var packageReferences = new List<CsprojReferenceInfo>();
        var projectReferences = new List<CsprojReferenceInfo>();
        var effectiveProperties = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);

        foreach (var propertyGroup in root.Elements().Where(element => element.Name.LocalName == "PropertyGroup"))
        {
            var condition = propertyGroup.Attribute("Condition")?.Value;
            var groupProperties = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);

            foreach (var property in propertyGroup.Elements())
            {
                if (property.HasElements)
                {
                    continue;
                }

                var value = property.Value.Trim();
                groupProperties[property.Name.LocalName] = value;
                effectiveProperties[property.Name.LocalName] = value;
            }

            propertyGroups.Add(new CsprojPropertyGroupInfo(condition, groupProperties));
        }

        foreach (var itemGroup in root.Elements().Where(element => element.Name.LocalName == "ItemGroup"))
        {
            foreach (var packageReference in itemGroup.Elements().Where(element => element.Name.LocalName == "PackageReference"))
            {
                var include = packageReference.Attribute("Include")?.Value ?? packageReference.Attribute("Update")?.Value ?? string.Empty;
                if (string.IsNullOrWhiteSpace(include))
                {
                    continue;
                }

                packageReferences.Add(ReadReference(packageReference, include));
            }

            foreach (var projectReference in itemGroup.Elements().Where(element => element.Name.LocalName == "ProjectReference"))
            {
                var include = projectReference.Attribute("Include")?.Value ?? string.Empty;
                if (string.IsNullOrWhiteSpace(include))
                {
                    continue;
                }

                projectReferences.Add(ReadReference(projectReference, include));
            }
        }

        var targetFrameworks = new List<string>();
        if (effectiveProperties.TryGetValue("TargetFrameworks", out var targetFrameworksValue))
        {
            targetFrameworks.AddRange(targetFrameworksValue.Split(';', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries));
        }
        else if (effectiveProperties.TryGetValue("TargetFramework", out var targetFrameworkValue))
        {
            targetFrameworks.Add(targetFrameworkValue);
        }

        return new CsprojReadModel(
            Path: Path.GetFullPath(path),
            IsSdkStyle: isSdkStyle,
            Sdk: sdk,
            TargetFrameworks: targetFrameworks,
            TargetFramework: effectiveProperties.TryGetValue("TargetFramework", out var targetFramework) ? targetFramework : null,
            EffectiveProperties: effectiveProperties,
            PropertyGroups: propertyGroups,
            PackageReferences: packageReferences,
            ProjectReferences: projectReferences);
    }

    private static CsprojReferenceInfo ReadReference(XElement element, string include)
    {
        var metadata = element.Elements()
            .Where(child => !child.HasElements)
            .ToDictionary(child => child.Name.LocalName, child => child.Value.Trim(), StringComparer.OrdinalIgnoreCase);

        return new CsprojReferenceInfo(include, element.Attribute("Condition")?.Value, metadata);
    }
}
