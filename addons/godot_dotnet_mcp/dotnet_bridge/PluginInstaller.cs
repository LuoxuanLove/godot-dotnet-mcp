namespace GodotDotnetMcp.DotnetBridge;

internal static class PluginInstaller
{
    private static readonly string PluginRelativePath = Path.Combine("addons", "godot_dotnet_mcp");
    private static readonly HashSet<string> IgnoredDirectoryNames = new(StringComparer.OrdinalIgnoreCase)
    {
        ".git",
        ".idea",
        ".vs",
        "__pycache__",
        "bin",
        "custom_tools",
        "obj",
    };

    public static async Task<int> RunAsync(string[] args, Stream output, TextWriter error, CancellationToken cancellationToken)
    {
        if (!TryParseArguments(args, out var installArgs, out var parseError))
        {
            await error.WriteLineAsync(parseError ?? "Invalid plugin installation arguments.");
            return 2;
        }

        if (string.IsNullOrWhiteSpace(installArgs.ProjectPath))
        {
            await error.WriteLineAsync("Missing required --project-path argument.");
            return 2;
        }

        var projectRoot = ResolveProjectRoot(installArgs.ProjectPath);
        if (projectRoot is null)
        {
            await error.WriteLineAsync($"Project directory not found: {installArgs.ProjectPath}");
            return 2;
        }

        var projectFile = Path.Combine(projectRoot, "project.godot");
        if (!File.Exists(projectFile))
        {
            await error.WriteLineAsync($"Not a Godot project root (missing project.godot): {projectRoot}");
            return 2;
        }

        var sourceRoot = ResolveSourceRoot(installArgs.SourcePath);
        if (sourceRoot is null)
        {
            await error.WriteLineAsync("Plugin source directory not found. Pass --source-path or package the plugin folder next to the Bridge exe.");
            return 2;
        }

        var targetRoot = Path.Combine(projectRoot, PluginRelativePath);
        if (Directory.Exists(targetRoot))
        {
            if (!installArgs.Force)
            {
                await error.WriteLineAsync($"Plugin already exists at {targetRoot}. Re-run with --force to overwrite.");
                return 3;
            }

            Directory.Delete(targetRoot, recursive: true);
        }

        Directory.CreateDirectory(targetRoot);
        var fileCount = CopyDirectory(sourceRoot, targetRoot, overwrite: true);
        var payload = new
        {
            success = true,
            projectPath = projectRoot,
            pluginPath = targetRoot,
            sourcePath = sourceRoot,
            installedFiles = fileCount,
            message = "Plugin installed successfully."
        };

        await BridgeApplication.WriteJsonAsync(output, payload, cancellationToken);
        return 0;
    }

    private static bool TryParseArguments(string[] args, out PluginInstallArguments parsed, out string? error)
    {
        parsed = new PluginInstallArguments(string.Empty, string.Empty, false);
        error = null;

        var projectPath = string.Empty;
        var sourcePath = string.Empty;
        var force = false;

        for (var index = 0; index < args.Length; index++)
        {
            var arg = args[index];
            switch (arg)
            {
                case "--project-path":
                case "--project":
                    if (index + 1 >= args.Length)
                    {
                        error = "Missing value for --project-path.";
                        return false;
                    }

                    projectPath = args[++index];
                    break;
                case "--source-path":
                case "--source":
                    if (index + 1 >= args.Length)
                    {
                        error = "Missing value for --source-path.";
                        return false;
                    }

                    sourcePath = args[++index];
                    break;
                case "--force":
                    force = true;
                    break;
                default:
                    if (arg.StartsWith('-'))
                    {
                        error = $"Unrecognized plugin install argument: {arg}";
                        return false;
                    }

                    if (string.IsNullOrWhiteSpace(projectPath))
                    {
                        projectPath = arg;
                    }
                    else if (string.IsNullOrWhiteSpace(sourcePath))
                    {
                        sourcePath = arg;
                    }
                    else
                    {
                        error = $"Unrecognized plugin install value: {arg}";
                        return false;
                    }

                    break;
            }
        }

        parsed = new PluginInstallArguments(projectPath, sourcePath, force);
        return true;
    }

    private static string? ResolveProjectRoot(string inputPath)
    {
        var resolved = Path.GetFullPath(Environment.ExpandEnvironmentVariables(inputPath));
        if (File.Exists(resolved) && string.Equals(Path.GetFileName(resolved), "project.godot", StringComparison.OrdinalIgnoreCase))
        {
            return Path.GetDirectoryName(resolved);
        }

        if (Directory.Exists(resolved))
        {
            return resolved;
        }

        return null;
    }

    private static string? ResolveSourceRoot(string inputPath)
    {
        if (!string.IsNullOrWhiteSpace(inputPath))
        {
            var explicitSource = Path.GetFullPath(Environment.ExpandEnvironmentVariables(inputPath));
            return Directory.Exists(explicitSource) ? explicitSource : null;
        }

        var baseDirectory = AppContext.BaseDirectory;
        var candidates = new[]
        {
            Path.Combine(baseDirectory, "plugin"),
            Path.Combine(baseDirectory, PluginRelativePath),
            Path.GetFullPath(Path.Combine(baseDirectory, "..", "..", "plugin")),
            Path.GetFullPath(Path.Combine(baseDirectory, "..", "..", "addons", "godot_dotnet_mcp")),
        };

        foreach (var candidate in candidates)
        {
            if (Directory.Exists(candidate))
            {
                return candidate;
            }
        }

        return null;
    }

    private static int CopyDirectory(string sourceRoot, string targetRoot, bool overwrite)
    {
        var fileCount = 0;
        var stack = new Stack<(string Source, string Target)>();
        stack.Push((sourceRoot, targetRoot));

        while (stack.Count > 0)
        {
            var (sourceDirectory, targetDirectory) = stack.Pop();
            Directory.CreateDirectory(targetDirectory);

            foreach (var filePath in Directory.GetFiles(sourceDirectory))
            {
                if (filePath.EndsWith(".import", StringComparison.OrdinalIgnoreCase))
                {
                    continue;
                }

                var targetFilePath = Path.Combine(targetDirectory, Path.GetFileName(filePath));
                File.Copy(filePath, targetFilePath, overwrite);
                fileCount++;
            }

            foreach (var childDirectory in Directory.GetDirectories(sourceDirectory))
            {
                if (IgnoredDirectoryNames.Contains(Path.GetFileName(childDirectory)))
                {
                    continue;
                }

                var targetChildDirectory = Path.Combine(targetDirectory, Path.GetFileName(childDirectory));
                stack.Push((childDirectory, targetChildDirectory));
            }
        }

        return fileCount;
    }

    private sealed record PluginInstallArguments(string ProjectPath, string SourcePath, bool Force);
}
