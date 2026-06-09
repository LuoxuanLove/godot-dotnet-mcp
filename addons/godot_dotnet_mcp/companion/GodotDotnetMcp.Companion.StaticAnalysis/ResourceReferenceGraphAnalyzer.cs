using System.Text.RegularExpressions;

namespace GodotDotnetMcp.Companion.StaticAnalysis;

public sealed class ResourceReferenceGraphAnalyzer
{
    private static readonly Regex AttributePattern = new(
        """(?<name>[A-Za-z_][A-Za-z0-9_]*)=(?:"(?<quoted>[^"]*)"|(?<bare>[^\s\]]+))""",
        RegexOptions.CultureInvariant);

    private static readonly Regex ExtResourceUsagePattern = new(
        """ExtResource\("(?<id>[^"]+)"\)""",
        RegexOptions.CultureInvariant);

    private static readonly Regex SubResourceUsagePattern = new(
        """SubResource\("(?<id>[^"]+)"\)""",
        RegexOptions.CultureInvariant);

    private static readonly Regex PreloadUsagePattern = new(
        """preload\("(?<path>res://[^"]+)"\)""",
        RegexOptions.CultureInvariant);

    private static readonly Regex LoadUsagePattern = new(
        """load\("(?<path>res://[^"]+)"\)""",
        RegexOptions.CultureInvariant);

    private static readonly Regex UidUsagePattern = new(
        """uid://[A-Za-z0-9_\-]+""",
        RegexOptions.CultureInvariant);

    public ResourceReferenceGraph Analyze(string projectRoot)
    {
        if (string.IsNullOrWhiteSpace(projectRoot))
        {
            throw new ArgumentException("Project root is required.", nameof(projectRoot));
        }

        var normalizedRoot = Path.GetFullPath(projectRoot);
        var files = EnumerateResourceFiles(normalizedRoot)
            .OrderBy(path => path, StringComparerForPlatform())
            .Select(path => BuildFileItem(normalizedRoot, path))
            .ToArray();

        var externalResources = new List<ResourceExternalResourceGraphItem>();
        var subResources = new List<ResourceSubResourceGraphItem>();
        var referenceUsages = new List<ResourceReferenceUsageGraphItem>();
        var diagnostics = new List<ResourceGraphDiagnostic>();

        foreach (var file in files)
        {
            if (!file.SupportedTextFormat)
            {
                diagnostics.Add(new ResourceGraphDiagnostic(
                    ResourcePath: file.ResourcePath,
                    Line: null,
                    Severity: ResourceGraphDiagnosticSeverity.Info,
                    Code: "resource_graph_binary_resource_unsupported",
                    Message: "Binary .res resources are recorded but not parsed by static/headless analysis."));
                continue;
            }

            AnalyzeTextResource(
                normalizedRoot,
                file,
                externalResources,
                subResources,
                referenceUsages,
                diagnostics);
        }

        return new ResourceReferenceGraph(
            Files: files,
            ExternalResources: externalResources,
            SubResources: subResources,
            ReferenceUsages: referenceUsages,
            Diagnostics: diagnostics);
    }

    private static void AnalyzeTextResource(
        string projectRoot,
        ResourceFileGraphItem file,
        List<ResourceExternalResourceGraphItem> externalResources,
        List<ResourceSubResourceGraphItem> subResources,
        List<ResourceReferenceUsageGraphItem> referenceUsages,
        List<ResourceGraphDiagnostic> diagnostics)
    {
        var externalById = new Dictionary<string, ResourceExternalResourceGraphItem>(StringComparer.Ordinal);
        var subResourceIds = new HashSet<string>(StringComparer.Ordinal);
        try
        {
            var lines = File.ReadAllLines(file.FilePath);
            for (var index = 0; index < lines.Length; index++)
            {
                var lineNumber = index + 1;
                var line = lines[index];
                if (line.StartsWith("[ext_resource ", StringComparison.Ordinal))
                {
                    var item = ParseExternalResource(projectRoot, file.ResourcePath, line, lineNumber, diagnostics);
                    if (item is not null)
                    {
                        externalResources.Add(item);
                        externalById[item.Id] = item;
                    }
                }
                else if (line.StartsWith("[sub_resource ", StringComparison.Ordinal))
                {
                    var item = ParseSubResource(file.ResourcePath, line, lineNumber, diagnostics);
                    if (item is not null)
                    {
                        subResources.Add(item);
                        subResourceIds.Add(item.Id);
                    }
                }
            }

            for (var index = 0; index < lines.Length; index++)
            {
                var lineNumber = index + 1;
                var line = lines[index];
                RecordReferenceUsages(projectRoot, file.ResourcePath, line, lineNumber, externalById, subResourceIds, referenceUsages, diagnostics);
            }
        }
        catch (Exception exception) when (IsRecoverableReadException(exception))
        {
            diagnostics.Add(new ResourceGraphDiagnostic(
                ResourcePath: file.ResourcePath,
                Line: null,
                Severity: ResourceGraphDiagnosticSeverity.Error,
                Code: "resource_graph_resource_unreadable",
                Message: $"Unable to read resource file: {exception.Message}"));
        }
    }

    private static ResourceExternalResourceGraphItem? ParseExternalResource(
        string projectRoot,
        string sourceResourcePath,
        string line,
        int lineNumber,
        List<ResourceGraphDiagnostic> diagnostics)
    {
        var attributes = ParseAttributes(line);
        if (!attributes.TryGetValue("id", out var id) || string.IsNullOrWhiteSpace(id))
        {
            diagnostics.Add(MissingAttribute(sourceResourcePath, lineNumber, "ext_resource", "id"));
            return null;
        }

        attributes.TryGetValue("path", out var path);
        attributes.TryGetValue("uid", out var uid);
        var resolved = ResolveResourcePath(projectRoot, path);
        if (path is not null && resolved.Invalid)
        {
            diagnostics.Add(InvalidResourcePath(sourceResourcePath, lineNumber, path));
        }
        else if (path is not null && resolved.IsInsideProjectRoot == false)
        {
            diagnostics.Add(new ResourceGraphDiagnostic(
                ResourcePath: sourceResourcePath,
                Line: lineNumber,
                Severity: ResourceGraphDiagnosticSeverity.Warning,
                Code: "resource_graph_reference_outside_project",
                Message: $"External resource '{id}' resolves outside the project root."));
        }
        else if (path is not null && resolved.IsInsideProjectRoot == true && !resolved.Exists)
        {
            diagnostics.Add(MissingFile(sourceResourcePath, lineNumber, path));
        }

        return new ResourceExternalResourceGraphItem(
            SourceResourcePath: sourceResourcePath,
            Line: lineNumber,
            Id: id,
            Type: attributes.GetValueOrDefault("type"),
            Path: path,
            Uid: uid,
            ResolvedFilePath: resolved.FilePath,
            IsInsideProjectRoot: resolved.IsInsideProjectRoot,
            Exists: resolved.Exists);
    }

    private static ResourceSubResourceGraphItem? ParseSubResource(
        string sourceResourcePath,
        string line,
        int lineNumber,
        List<ResourceGraphDiagnostic> diagnostics)
    {
        var attributes = ParseAttributes(line);
        if (!attributes.TryGetValue("id", out var id) || string.IsNullOrWhiteSpace(id))
        {
            diagnostics.Add(MissingAttribute(sourceResourcePath, lineNumber, "sub_resource", "id"));
            return null;
        }

        return new ResourceSubResourceGraphItem(
            SourceResourcePath: sourceResourcePath,
            Line: lineNumber,
            Id: id,
            Type: attributes.GetValueOrDefault("type"));
    }

    private static void RecordReferenceUsages(
        string projectRoot,
        string sourceResourcePath,
        string line,
        int lineNumber,
        IReadOnlyDictionary<string, ResourceExternalResourceGraphItem> externalById,
        IReadOnlySet<string> subResourceIds,
        List<ResourceReferenceUsageGraphItem> referenceUsages,
        List<ResourceGraphDiagnostic> diagnostics)
    {
        foreach (Match match in ExtResourceUsagePattern.Matches(line))
        {
            var id = match.Groups["id"].Value;
            externalById.TryGetValue(id, out var external);
            referenceUsages.Add(new ResourceReferenceUsageGraphItem(
                SourceResourcePath: sourceResourcePath,
                Line: lineNumber,
                Kind: ResourceReferenceUsageKind.ExtResource,
                Reference: id,
                ResolvedResourcePath: external?.Path,
                ResolvedFilePath: external?.ResolvedFilePath,
                IsInsideProjectRoot: external?.IsInsideProjectRoot,
                Exists: external?.Exists ?? false));

            if (external is null)
            {
                diagnostics.Add(MissingDeclaration(sourceResourcePath, lineNumber, "ExtResource", id));
            }
        }

        foreach (Match match in SubResourceUsagePattern.Matches(line))
        {
            var id = match.Groups["id"].Value;
            var exists = subResourceIds.Contains(id);
            referenceUsages.Add(new ResourceReferenceUsageGraphItem(
                SourceResourcePath: sourceResourcePath,
                Line: lineNumber,
                Kind: ResourceReferenceUsageKind.SubResource,
                Reference: id,
                ResolvedResourcePath: null,
                ResolvedFilePath: null,
                IsInsideProjectRoot: null,
                Exists: exists));

            if (!exists)
            {
                diagnostics.Add(MissingDeclaration(sourceResourcePath, lineNumber, "SubResource", id));
            }
        }

        RecordPathUsages(projectRoot, sourceResourcePath, line, lineNumber, PreloadUsagePattern, ResourceReferenceUsageKind.Preload, referenceUsages, diagnostics);
        RecordPathUsages(projectRoot, sourceResourcePath, line, lineNumber, LoadUsagePattern, ResourceReferenceUsageKind.Load, referenceUsages, diagnostics);

        foreach (Match match in UidUsagePattern.Matches(line))
        {
            referenceUsages.Add(new ResourceReferenceUsageGraphItem(
                SourceResourcePath: sourceResourcePath,
                Line: lineNumber,
                Kind: ResourceReferenceUsageKind.Uid,
                Reference: match.Value,
                ResolvedResourcePath: match.Value,
                ResolvedFilePath: null,
                IsInsideProjectRoot: null,
                Exists: false));
        }
    }

    private static void RecordPathUsages(
        string projectRoot,
        string sourceResourcePath,
        string line,
        int lineNumber,
        Regex pattern,
        ResourceReferenceUsageKind kind,
        List<ResourceReferenceUsageGraphItem> referenceUsages,
        List<ResourceGraphDiagnostic> diagnostics)
    {
        foreach (Match match in pattern.Matches(line))
        {
            var path = match.Groups["path"].Value;
            var resolved = ResolveResourcePath(projectRoot, path);
            referenceUsages.Add(new ResourceReferenceUsageGraphItem(
                SourceResourcePath: sourceResourcePath,
                Line: lineNumber,
                Kind: kind,
                Reference: path,
                ResolvedResourcePath: path,
                ResolvedFilePath: resolved.FilePath,
                IsInsideProjectRoot: resolved.IsInsideProjectRoot,
                Exists: resolved.Exists));

            if (resolved.IsInsideProjectRoot == false)
            {
                diagnostics.Add(new ResourceGraphDiagnostic(
                    ResourcePath: sourceResourcePath,
                    Line: lineNumber,
                    Severity: ResourceGraphDiagnosticSeverity.Warning,
                    Code: "resource_graph_reference_outside_project",
                    Message: $"{kind} reference resolves outside the project root."));
            }
            else if (resolved.Invalid)
            {
                diagnostics.Add(InvalidResourcePath(sourceResourcePath, lineNumber, path));
            }
            else if (resolved.IsInsideProjectRoot == true && !resolved.Exists)
            {
                diagnostics.Add(MissingFile(sourceResourcePath, lineNumber, path));
            }
        }
    }

    private static Dictionary<string, string> ParseAttributes(string line)
    {
        var attributes = new Dictionary<string, string>(StringComparer.Ordinal);
        foreach (Match match in AttributePattern.Matches(line))
        {
            attributes[match.Groups["name"].Value] =
                match.Groups["quoted"].Success ? match.Groups["quoted"].Value : match.Groups["bare"].Value;
        }

        return attributes;
    }

    private static ResourceFileGraphItem BuildFileItem(string projectRoot, string filePath)
    {
        var extension = Path.GetExtension(filePath);
        var kind = extension.Equals(".tscn", StringComparison.OrdinalIgnoreCase)
            ? ResourceFileKind.Scene
            : extension.Equals(".tres", StringComparison.OrdinalIgnoreCase)
                ? ResourceFileKind.TextResource
                : ResourceFileKind.BinaryResource;

        return new ResourceFileGraphItem(
            ResourcePath: ToResourcePath(projectRoot, filePath),
            FilePath: filePath,
            Kind: kind,
            SupportedTextFormat: kind is ResourceFileKind.Scene or ResourceFileKind.TextResource);
    }

    private static ResourcePathResolution ResolveResourcePath(string projectRoot, string? resourcePath)
    {
        if (string.IsNullOrWhiteSpace(resourcePath) || !resourcePath.StartsWith("res://", StringComparison.Ordinal))
        {
            return new ResourcePathResolution(null, null, false, false);
        }

        try
        {
            var relativePath = resourcePath["res://".Length..].Replace('/', Path.DirectorySeparatorChar);
            var filePath = Path.GetFullPath(relativePath, projectRoot);
            var isInside = IsInside(projectRoot, filePath);
            return new ResourcePathResolution(filePath, isInside, isInside && File.Exists(filePath), false);
        }
        catch (Exception exception) when (IsRecoverablePathException(exception))
        {
            return new ResourcePathResolution(null, null, false, true);
        }
    }

    private static ResourceGraphDiagnostic MissingAttribute(string resourcePath, int line, string context, string attribute)
    {
        return new ResourceGraphDiagnostic(
            ResourcePath: resourcePath,
            Line: line,
            Severity: ResourceGraphDiagnosticSeverity.Warning,
            Code: "resource_graph_missing_required_attribute",
            Message: $"{context} without '{attribute}' was ignored.");
    }

    private static ResourceGraphDiagnostic MissingDeclaration(string resourcePath, int line, string kind, string id)
    {
        return new ResourceGraphDiagnostic(
            ResourcePath: resourcePath,
            Line: line,
            Severity: ResourceGraphDiagnosticSeverity.Warning,
            Code: "resource_graph_missing_reference_declaration",
            Message: $"{kind} reference '{id}' has no declaration earlier in the same resource file.");
    }

    private static ResourceGraphDiagnostic InvalidResourcePath(string resourcePath, int line, string referencedPath)
    {
        return new ResourceGraphDiagnostic(
            ResourcePath: resourcePath,
            Line: line,
            Severity: ResourceGraphDiagnosticSeverity.Warning,
            Code: "resource_graph_reference_invalid_path",
            Message: $"Referenced resource '{referencedPath}' could not be resolved as a local project path.");
    }

    private static ResourceGraphDiagnostic MissingFile(string resourcePath, int line, string referencedPath)
    {
        return new ResourceGraphDiagnostic(
            ResourcePath: resourcePath,
            Line: line,
            Severity: ResourceGraphDiagnosticSeverity.Warning,
            Code: "resource_graph_reference_missing_file",
            Message: $"Referenced resource '{referencedPath}' does not exist inside the project root.");
    }

    private static IEnumerable<string> EnumerateResourceFiles(string projectRoot)
    {
        var stack = new Stack<DirectoryInfo>();
        stack.Push(new DirectoryInfo(projectRoot));

        while (stack.Count > 0)
        {
            var directory = stack.Pop();
            foreach (var file in SafeEnumerateFiles(directory))
            {
                if ((file.Attributes & FileAttributes.ReparsePoint) != 0)
                {
                    continue;
                }

                var normalizedPath = Path.GetFullPath(file.FullName);
                if (IsInside(projectRoot, normalizedPath))
                {
                    yield return normalizedPath;
                }
            }

            foreach (var childDirectory in SafeEnumerateDirectories(directory))
            {
                if (ShouldEnterDirectory(projectRoot, childDirectory))
                {
                    stack.Push(childDirectory);
                }
            }
        }
    }

    private static IEnumerable<FileInfo> SafeEnumerateFiles(DirectoryInfo directory)
    {
        try
        {
            return directory.EnumerateFiles("*", SearchOption.TopDirectoryOnly)
                .Where(file => IsResourceExtension(file.Extension))
                .ToArray();
        }
        catch (UnauthorizedAccessException)
        {
            return [];
        }
        catch (IOException)
        {
            return [];
        }
    }

    private static IEnumerable<DirectoryInfo> SafeEnumerateDirectories(DirectoryInfo directory)
    {
        try
        {
            return directory.EnumerateDirectories("*", SearchOption.TopDirectoryOnly).ToArray();
        }
        catch (UnauthorizedAccessException)
        {
            return [];
        }
        catch (IOException)
        {
            return [];
        }
    }

    private static bool ShouldEnterDirectory(string projectRoot, DirectoryInfo directory)
    {
        var attributes = directory.Attributes;
        if ((attributes & FileAttributes.Hidden) != 0 ||
            (attributes & FileAttributes.System) != 0 ||
            (attributes & FileAttributes.ReparsePoint) != 0)
        {
            return false;
        }

        if (directory.Name.StartsWith(".", StringComparison.Ordinal))
        {
            return false;
        }

        var normalizedDirectory = Path.GetFullPath(directory.FullName);
        return IsInside(projectRoot, normalizedDirectory);
    }

    private static bool IsResourceExtension(string extension)
    {
        return extension.Equals(".tscn", StringComparison.OrdinalIgnoreCase) ||
            extension.Equals(".tres", StringComparison.OrdinalIgnoreCase) ||
            extension.Equals(".res", StringComparison.OrdinalIgnoreCase);
    }

    private static string ToResourcePath(string projectRoot, string filePath)
    {
        var relativePath = Path.GetRelativePath(projectRoot, filePath)
            .Replace(Path.DirectorySeparatorChar, '/')
            .Replace(Path.AltDirectorySeparatorChar, '/');
        return "res://" + relativePath;
    }

    private static bool IsRecoverableReadException(Exception exception)
    {
        return exception is UnauthorizedAccessException or IOException;
    }

    private static bool IsRecoverablePathException(Exception exception)
    {
        return exception is ArgumentException or NotSupportedException or PathTooLongException;
    }

    private static bool IsInside(string root, string path)
    {
        var normalizedRoot = Path.TrimEndingDirectorySeparator(Path.GetFullPath(root)) + Path.DirectorySeparatorChar;
        var normalizedPath = Path.GetFullPath(path);
        return normalizedPath.StartsWith(normalizedRoot, StringComparisonForPlatform());
    }

    private static StringComparer StringComparerForPlatform()
    {
        return OperatingSystem.IsWindows() ? StringComparer.OrdinalIgnoreCase : StringComparer.Ordinal;
    }

    private static StringComparison StringComparisonForPlatform()
    {
        return OperatingSystem.IsWindows() ? StringComparison.OrdinalIgnoreCase : StringComparison.Ordinal;
    }

    private sealed record ResourcePathResolution(
        string? FilePath,
        bool? IsInsideProjectRoot,
        bool Exists,
        bool Invalid);
}
