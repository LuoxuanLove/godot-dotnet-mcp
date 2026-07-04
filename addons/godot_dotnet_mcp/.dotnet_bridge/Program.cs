using System.Text.Json;
using System.Reflection;

namespace GodotDotnetMcp.DotnetBridge;

internal static class Program
{
    private static readonly string Version =
        typeof(Program).Assembly.GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion
        ?? typeof(Program).Assembly.GetName().Version?.ToString()
        ?? "0.0.0";
    private const int DefaultTimeoutMs = 15000;
    private const int MaxTimeoutMs = 120000;
    private const string ResponseRootsEnvironmentVariable = "GODOT_DOTNET_MCP_RESPONSE_ROOTS";

    public static async Task<int> Main(string[] args)
    {
        var responseJsonFile = BridgeCommandOptions.FindResponseJsonFile(args);
        BridgeCommandOptions? options = null;
        try
        {
            options = BridgeCommandOptions.Parse(args);
            if (options.Command is null || IsCommand(options.Command, "--capabilities"))
            {
                WriteJson(options.ResponseJsonFile, new
                {
                    success = true,
                    component = "godot-dotnet-mcp-roslyn-runtime",
                    version = Version,
                    mode = "syntax",
                    transport = "single_process_json",
                    tools = BridgeToolCatalog.GetTools(),
                });
                return 0;
            }

            if (options.Command is not null && options.Arguments.Count >= 2 && IsCommand(options.Command, "--call"))
            {
                var toolName = options.Arguments[0];
                using var document = JsonDocument.Parse(options.Arguments[1]);
                return await ExecuteCallAsync(toolName, document.RootElement, options);
            }

            if (options.Command is not null && options.Arguments.Count >= 2 && IsCommand(options.Command, "--call-json-file"))
            {
                var toolName = options.Arguments[0];
                using var document = JsonDocument.Parse(await File.ReadAllTextAsync(options.Arguments[1]));
                return await ExecuteCallAsync(toolName, document.RootElement, options);
            }

            WriteJson(options.ResponseJsonFile, new
            {
                success = false,
                error = "Usage: DotnetBridge --capabilities | --call <tool_name> <json_arguments> | --call-json-file <tool_name> <json_file>",
            });
            return 64;
        }
        catch (Exception ex)
        {
            WriteJsonOrConsole(options?.ResponseJsonFile ?? responseJsonFile, new
            {
                success = false,
                error = ex.Message,
                exception = ex.GetType().Name,
            });
            return 1;
        }
    }

    private static bool IsCommand(string actual, string expected)
    {
        return string.Equals(actual, expected, StringComparison.OrdinalIgnoreCase);
    }

    private static async Task<int> ExecuteCallAsync(string toolName, JsonElement arguments, BridgeCommandOptions options)
    {
        using var timeoutCts = new CancellationTokenSource(options.TimeoutMs);
        try
        {
            var response = await BridgeToolDispatcher.ExecuteAsync(toolName, arguments, timeoutCts.Token);
            WriteJson(options.ResponseJsonFile, new
            {
                success = !response.IsError,
                isError = response.IsError,
                structuredContent = response.StructuredContent,
                content = response.TextContent,
            });
            return response.IsError ? 2 : 0;
        }
        catch (OperationCanceledException) when (timeoutCts.IsCancellationRequested)
        {
            WriteJson(options.ResponseJsonFile, new
            {
                success = false,
                isError = true,
                error = $"Tool '{toolName}' timed out after {options.TimeoutMs} ms.",
                structuredContent = new
                {
                    error = "runtime_timeout",
                    toolName,
                    timeoutMs = options.TimeoutMs,
                },
                content = $"Tool '{toolName}' timed out after {options.TimeoutMs} ms.",
            });
            return 124;
        }
    }

    private static void WriteJson(string? responseJsonFile, object payload)
    {
        var json = JsonSerializer.Serialize(payload, BridgeSerialization.JsonOptions);
        if (!string.IsNullOrWhiteSpace(responseJsonFile))
        {
            var resolved = ResolveResponseJsonFile(responseJsonFile!);
            Directory.CreateDirectory(Path.GetDirectoryName(resolved)!);
            File.WriteAllText(resolved, json);
            return;
        }

        Console.WriteLine(json);
    }

    private static void WriteJsonOrConsole(string? responseJsonFile, object payload)
    {
        try
        {
            WriteJson(responseJsonFile, payload);
        }
        catch
        {
            WriteJson(null, payload);
        }
    }

    private static string ResolveResponseJsonFile(string responseJsonFile)
    {
        var resolved = Path.GetFullPath(Environment.ExpandEnvironmentVariables(responseJsonFile));
        if (Directory.Exists(resolved))
        {
            throw new ArgumentException("--response-json-file must point at a JSON file, not a directory.");
        }

        if (!Path.GetExtension(resolved).Equals(".json", StringComparison.OrdinalIgnoreCase))
        {
            throw new ArgumentException("--response-json-file must point at a .json file.");
        }

        var allowedRoots = GetResponseJsonAllowedRoots();
        var allowedRoot = allowedRoots.FirstOrDefault(root => IsPathInsideRoot(resolved, root));
        if (string.IsNullOrWhiteSpace(allowedRoot))
        {
            throw new UnauthorizedAccessException("response_json_file_outside_allowed_roots: --response-json-file must stay inside the Godot project root or GODOT_DOTNET_MCP_RESPONSE_ROOTS.");
        }

        var parent = Path.GetDirectoryName(resolved);
        if (string.IsNullOrWhiteSpace(parent))
        {
            throw new ArgumentException("--response-json-file must include a parent directory.");
        }

        if (WorkspacePathResolver.ResolvedPathUsesReparsePointSegment(allowedRoot, parent)
            || (File.Exists(resolved) && WorkspacePathResolver.ResolvedPathUsesReparsePointSegment(allowedRoot, resolved)))
        {
            throw new UnauthorizedAccessException("response_json_file_reparse_point: --response-json-file must not traverse symlink, junction, or reparse-point segments.");
        }

        return resolved;
    }

    private static IReadOnlyList<string> GetResponseJsonAllowedRoots()
    {
        var roots = new List<string> { WorkspacePathResolver.ProjectRootPath };
        var configuredRoots = Environment.GetEnvironmentVariable(ResponseRootsEnvironmentVariable);
        if (!string.IsNullOrWhiteSpace(configuredRoots))
        {
            roots.AddRange(configuredRoots
                .Split(Path.PathSeparator, StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
                .Select(root => Path.GetFullPath(Environment.ExpandEnvironmentVariables(root))));
        }

        return roots
            .Distinct(OperatingSystem.IsWindows() ? StringComparer.OrdinalIgnoreCase : StringComparer.Ordinal)
            .ToArray();
    }

    private static bool IsPathInsideRoot(string path, string root)
    {
        var resolvedPath = Path.GetFullPath(path);
        var resolvedRoot = Path.GetFullPath(root);
        return string.Equals(
                Path.TrimEndingDirectorySeparator(resolvedPath),
                Path.TrimEndingDirectorySeparator(resolvedRoot),
                PathComparison)
            || resolvedPath.StartsWith(EnsureTrailingSeparator(resolvedRoot), PathComparison);
    }

    private static string EnsureTrailingSeparator(string path)
    {
        var normalized = Path.GetFullPath(path);
        return Path.EndsInDirectorySeparator(normalized)
            ? normalized
            : normalized + Path.DirectorySeparatorChar;
    }

    private static StringComparison PathComparison =>
        OperatingSystem.IsWindows() ? StringComparison.OrdinalIgnoreCase : StringComparison.Ordinal;

    private sealed record BridgeCommandOptions(string? Command, IReadOnlyList<string> Arguments, int TimeoutMs, string? ResponseJsonFile)
    {
        public static string? FindResponseJsonFile(IReadOnlyList<string> args)
        {
            for (var index = 0; index < args.Count - 1; index++)
            {
                if (IsCommand(args[index], "--response-json-file") && !string.IsNullOrWhiteSpace(args[index + 1]))
                {
                    return args[index + 1];
                }
            }

            return null;
        }

        public static BridgeCommandOptions Parse(IReadOnlyList<string> args)
        {
            var timeoutMs = DefaultTimeoutMs;
            string? responseJsonFile = null;
            string? command = null;
            var commandArgs = new List<string>();

            for (var index = 0; index < args.Count; index++)
            {
                var arg = args[index];
                if (IsCommand(arg, "--timeout-ms"))
                {
                    if (index + 1 >= args.Count || !int.TryParse(args[index + 1], out var parsedTimeout))
                    {
                        throw new ArgumentException("--timeout-ms requires an integer value.");
                    }

                    timeoutMs = Math.Clamp(parsedTimeout, 1, MaxTimeoutMs);
                    index++;
                    continue;
                }

                if (IsCommand(arg, "--response-json-file"))
                {
                    if (index + 1 >= args.Count || string.IsNullOrWhiteSpace(args[index + 1]))
                    {
                        throw new ArgumentException("--response-json-file requires a path.");
                    }

                    responseJsonFile = args[index + 1];
                    index++;
                    continue;
                }

                command = arg;
                for (var commandIndex = index + 1; commandIndex < args.Count; commandIndex++)
                {
                    commandArgs.Add(args[commandIndex]);
                }
                break;
            }

            return new BridgeCommandOptions(command, commandArgs, timeoutMs, responseJsonFile);
        }
    }
}
