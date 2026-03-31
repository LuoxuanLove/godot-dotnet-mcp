using System.Diagnostics;
using System.Text;
using System.Text.Json;

internal static class Program
{
    private const int HarnessTimeoutMs = 120_000;
    private static readonly string[] LeakWarningMarkers =
    [
        "ObjectDB instances leaked at exit",
        "resources still in use at exit",
    ];

    private static async Task<int> Main(string[] args)
    {
        Console.OutputEncoding = Encoding.UTF8;

        var repoRoot = ResolveRepoRoot();
        var allowSkipMissingGodot = args.Any(arg => string.Equals(arg, "--allow-skip-missing-godot", StringComparison.OrdinalIgnoreCase));
        var keepStageRoot = args.Any(arg => string.Equals(arg, "--keep-stage-root", StringComparison.OrdinalIgnoreCase));
        var listCases = args.Any(arg => string.Equals(arg, "--list-cases", StringComparison.OrdinalIgnoreCase));
        var explicitGodotPath = GetOptionValue(args, "--godot-path")
            ?? Environment.GetEnvironmentVariable("GODOT_BIN")
            ?? Environment.GetEnvironmentVariable("GODOT4_BIN");

        if (string.IsNullOrWhiteSpace(explicitGodotPath) || !File.Exists(explicitGodotPath))
        {
            var summary = new
            {
                success = allowSkipMissingGodot,
                skipped = allowSkipMissingGodot,
                reason = "godot_executable_not_found",
                godotPath = explicitGodotPath ?? string.Empty,
            };
            Console.WriteLine(JsonSerializer.Serialize(summary, new JsonSerializerOptions { WriteIndented = true }));
            return allowSkipMissingGodot ? 0 : 1;
        }

        var stageRoot = Path.Combine(repoRoot, ".tmp", "godot_plugin_harness", Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(stageRoot);
        Process? process = null;
        Task<string>? stdoutTask = null;
        Task<string>? stderrTask = null;
        var preserveStageRoot = false;

        try
        {
            CopyDirectory(Path.Combine(repoRoot, "tests", "godot_plugin_harness_fixture"), stageRoot);
            CopyDirectory(Path.Combine(repoRoot, "addons", "godot_dotnet_mcp"), Path.Combine(stageRoot, "addons", "godot_dotnet_mcp"));
            var appDataRoot = Path.Combine(stageRoot, ".appdata");
            var localAppDataRoot = Path.Combine(stageRoot, ".localappdata");
            Directory.CreateDirectory(appDataRoot);
            Directory.CreateDirectory(localAppDataRoot);

            process = new Process
            {
                StartInfo = new ProcessStartInfo(explicitGodotPath)
                {
                    WorkingDirectory = stageRoot,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    UseShellExecute = false,
                    CreateNoWindow = true,
                }
            };
            process.StartInfo.Environment["APPDATA"] = appDataRoot;
            process.StartInfo.Environment["LOCALAPPDATA"] = localAppDataRoot;
            process.StartInfo.Environment["GODOT_PLUGIN_HARNESS_LIST_CASES"] = listCases ? "1" : "0";
            // Pre-set runtime environment variables for server_runtime_settings_projection test.
            // In Godot 4.3 headless mode, OS.has_environment() returns false for env vars
            // created via OS.set_environment() at runtime, even though OS.get_environment() works.
            // By pre-setting these in the parent process, they exist at Godot startup,
            // so has_environment() correctly returns true throughout the test.
            process.StartInfo.Environment["GODOT_DOTNET_MCP_SERVER_HOST"] = "10.0.0.8";
            process.StartInfo.Environment["GODOT_DOTNET_MCP_SERVER_PORT"] = "4100";
            process.StartInfo.ArgumentList.Add("--headless");
            process.StartInfo.ArgumentList.Add("--path");
            process.StartInfo.ArgumentList.Add(stageRoot);
            process.StartInfo.ArgumentList.Add("--script");
            process.StartInfo.ArgumentList.Add("res://tests/headless_suite_runner.gd");

            process.Start();
            stdoutTask = process.StandardOutput.ReadToEndAsync();
            stderrTask = process.StandardError.ReadToEndAsync();

            using var timeoutCts = new CancellationTokenSource(HarnessTimeoutMs);
            await process.WaitForExitAsync(timeoutCts.Token);

            var stdout = await stdoutTask;
            var stderr = await stderrTask;

            if (listCases)
            {
                var manifest = TryParsePrefixedJsonLine(stdout, "HARNESS_LIST_CASES_MANIFEST:")
                    ?? TryParseLastJsonLine(stdout)
                    ?? new
                    {
                        discovered = Array.Empty<object>(),
                        total = 0,
                        valid = 0,
                        invalid = 0,
                    };
                Console.WriteLine(JsonSerializer.Serialize(manifest, new JsonSerializerOptions { WriteIndented = true }));
                return process.ExitCode == 0 ? 0 : 1;
            }

            var leakWarningsDetected = ContainsLeakWarnings(stderr);
            var succeeded = process.ExitCode == 0 && !leakWarningsDetected;
            preserveStageRoot = keepStageRoot && !succeeded;
            var summary = new
            {
                success = succeeded,
                skipped = false,
                exitCode = process.ExitCode,
                leakWarningsDetected,
                reason = leakWarningsDetected ? "godot_exit_leaks_detected" : string.Empty,
                godotPath = explicitGodotPath,
                stageRoot,
                stageKept = preserveStageRoot,
                suite = TryParseLastJsonLine(stdout),
                stderr = string.IsNullOrWhiteSpace(stderr) ? string.Empty : stderr.Trim(),
            };

            Console.WriteLine(JsonSerializer.Serialize(summary, new JsonSerializerOptions { WriteIndented = true }));
            return succeeded ? 0 : 1;
        }
        catch (OperationCanceledException)
        {
            preserveStageRoot = keepStageRoot;
            TryKillProcessTree(process);
            var stdout = await TryReadOutputAsync(stdoutTask);
            var stderr = await TryReadOutputAsync(stderrTask);
            var summary = new
            {
                success = false,
                skipped = false,
                reason = "plugin_harness_timeout",
                timeoutMs = HarnessTimeoutMs,
                stageRoot,
                stageKept = preserveStageRoot,
                suite = TryParseLastJsonLine(stdout),
                stderr = string.IsNullOrWhiteSpace(stderr) ? string.Empty : stderr.Trim(),
            };
            Console.WriteLine(JsonSerializer.Serialize(summary, new JsonSerializerOptions { WriteIndented = true }));
            return 1;
        }
        finally
        {
            try
            {
                if (!preserveStageRoot && Directory.Exists(stageRoot))
                {
                    Directory.Delete(stageRoot, recursive: true);
                }
            }
            catch
            {
            }
        }
    }

    private static string? GetOptionValue(string[] args, string optionName)
    {
        for (var index = 0; index < args.Length; index++)
        {
            if (!string.Equals(args[index], optionName, StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }

            return index + 1 < args.Length ? args[index + 1] : null;
        }

        return null;
    }

    private static object? TryParseLastJsonLine(string stdout)
    {
        var candidate = stdout
            .Split(['\r', '\n'], StringSplitOptions.RemoveEmptyEntries)
            .Select(line => line.Trim())
            .LastOrDefault(line => line.StartsWith("{", StringComparison.Ordinal));
        if (string.IsNullOrWhiteSpace(candidate))
        {
            return new
            {
                rawOutput = stdout.Trim(),
            };
        }

        try
        {
            return JsonSerializer.Deserialize<object>(candidate);
        }
        catch
        {
            return new
            {
                rawOutput = stdout.Trim(),
            };
        }
    }

    private static object? TryParsePrefixedJsonLine(string stdout, string prefix)
    {
        if (string.IsNullOrWhiteSpace(stdout) || string.IsNullOrWhiteSpace(prefix))
        {
            return null;
        }

        var candidate = stdout
            .Split(['\r', '\n'], StringSplitOptions.RemoveEmptyEntries)
            .Select(line => line.Trim())
            .LastOrDefault(line => line.StartsWith(prefix, StringComparison.Ordinal));
        if (string.IsNullOrWhiteSpace(candidate))
        {
            return null;
        }

        var json = candidate[prefix.Length..].Trim();
        if (string.IsNullOrWhiteSpace(json))
        {
            return null;
        }

        try
        {
            return JsonSerializer.Deserialize<object>(json);
        }
        catch
        {
            return null;
        }
    }

    private static async Task<string> TryReadOutputAsync(Task<string>? task)
    {
        if (task is null)
        {
            return string.Empty;
        }

        try
        {
            return await task;
        }
        catch
        {
            return string.Empty;
        }
    }

    private static void TryKillProcessTree(Process? process)
    {
        if (process is null)
        {
            return;
        }

        try
        {
            if (!process.HasExited)
            {
                process.Kill(entireProcessTree: true);
                process.WaitForExit(5_000);
            }
        }
        catch
        {
        }
    }

    private static void CopyDirectory(string sourceRoot, string destinationRoot)
    {
        Directory.CreateDirectory(destinationRoot);

        foreach (var directory in Directory.EnumerateDirectories(sourceRoot, "*", SearchOption.AllDirectories))
        {
            var relativePath = Path.GetRelativePath(sourceRoot, directory);
            Directory.CreateDirectory(Path.Combine(destinationRoot, relativePath));
        }

        foreach (var file in Directory.EnumerateFiles(sourceRoot, "*", SearchOption.AllDirectories))
        {
            var relativePath = Path.GetRelativePath(sourceRoot, file);
            var destinationPath = Path.Combine(destinationRoot, relativePath);
            Directory.CreateDirectory(Path.GetDirectoryName(destinationPath)!);
            File.Copy(file, destinationPath, overwrite: true);
        }
    }

    private static string ResolveRepoRoot()
    {
        var candidates = new[]
        {
            Directory.GetCurrentDirectory(),
            AppContext.BaseDirectory,
        };

        foreach (var candidate in candidates)
        {
            var resolved = TryResolveRepoRoot(candidate);
            if (!string.IsNullOrWhiteSpace(resolved))
            {
                return resolved;
            }
        }

        throw new InvalidOperationException("Could not resolve repository root for the Godot plugin harness.");
    }

    private static string? TryResolveRepoRoot(string startPath)
    {
        var current = new DirectoryInfo(startPath);
        while (current is not null)
        {
            if (Directory.Exists(Path.Combine(current.FullName, "addons"))
                && Directory.Exists(Path.Combine(current.FullName, "central_server")))
            {
                return current.FullName;
            }

            current = current.Parent;
        }

        return null;
    }

    private static bool ContainsLeakWarnings(string stderr)
    {
        if (string.IsNullOrWhiteSpace(stderr))
        {
            return false;
        }

        return LeakWarningMarkers.Any(stderr.Contains);
    }
}
