using System.Diagnostics;
using System.Text;
using System.Text.Json;

internal static class Program
{
    private const int HarnessTimeoutMs = 120_000;

    private static async Task<int> Main(string[] args)
    {
        Console.OutputEncoding = Encoding.UTF8;

        var repoRoot = ResolveRepoRoot();
        var allowSkipMissingGodot = args.Any(arg => string.Equals(arg, "--allow-skip-missing-godot", StringComparison.OrdinalIgnoreCase));
        var keepStageRoot = args.Any(arg => string.Equals(arg, "--keep-stage-root", StringComparison.OrdinalIgnoreCase));
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
            preserveStageRoot = keepStageRoot && process.ExitCode != 0;
            var summary = new
            {
                success = process.ExitCode == 0,
                skipped = false,
                exitCode = process.ExitCode,
                godotPath = explicitGodotPath,
                stageRoot,
                stageKept = preserveStageRoot,
                suite = TryParseLastJsonLine(stdout),
                stderr = string.IsNullOrWhiteSpace(stderr) ? string.Empty : stderr.Trim(),
            };

            Console.WriteLine(JsonSerializer.Serialize(summary, new JsonSerializerOptions { WriteIndented = true }));
            return process.ExitCode == 0 ? 0 : 1;
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
}
