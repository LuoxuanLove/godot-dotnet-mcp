using System.Diagnostics;
using System.Text.Json;

internal static class Program
{
    private const int HarnessTimeoutMs = 120_000;

    private static async Task<int> Main(string[] args)
    {
        var repoRoot = ResolveRepoRoot();
        var allowSkipMissingGodot = args.Any(arg => string.Equals(arg, "--allow-skip-missing-godot", StringComparison.OrdinalIgnoreCase));
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

        try
        {
            CopyDirectory(Path.Combine(repoRoot, "tests", "godot_plugin_harness_fixture"), stageRoot);
            CopyDirectory(Path.Combine(repoRoot, "addons", "godot_dotnet_mcp"), Path.Combine(stageRoot, "addons", "godot_dotnet_mcp"));

            var process = new Process
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
            var stdoutTask = process.StandardOutput.ReadToEndAsync();
            var stderrTask = process.StandardError.ReadToEndAsync();

            using var timeoutCts = new CancellationTokenSource(HarnessTimeoutMs);
            await process.WaitForExitAsync(timeoutCts.Token);

            var stdout = await stdoutTask;
            var stderr = await stderrTask;
            var summary = new
            {
                success = process.ExitCode == 0,
                skipped = false,
                exitCode = process.ExitCode,
                godotPath = explicitGodotPath,
                stageRoot,
                suite = TryParseLastJsonLine(stdout),
                stderr = string.IsNullOrWhiteSpace(stderr) ? string.Empty : stderr.Trim(),
            };

            Console.WriteLine(JsonSerializer.Serialize(summary, new JsonSerializerOptions { WriteIndented = true }));
            return process.ExitCode == 0 ? 0 : 1;
        }
        catch (OperationCanceledException)
        {
            var summary = new
            {
                success = false,
                skipped = false,
                reason = "plugin_harness_timeout",
                timeoutMs = HarnessTimeoutMs,
                stageRoot,
            };
            Console.WriteLine(JsonSerializer.Serialize(summary, new JsonSerializerOptions { WriteIndented = true }));
            return 1;
        }
        finally
        {
            try
            {
                if (Directory.Exists(stageRoot))
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
        var current = new DirectoryInfo(Directory.GetCurrentDirectory());
        while (current is not null)
        {
            if (Directory.Exists(Path.Combine(current.FullName, "addons"))
                && Directory.Exists(Path.Combine(current.FullName, "central_server")))
            {
                return current.FullName;
            }

            current = current.Parent;
        }

        throw new InvalidOperationException("Could not resolve repository root for the Godot plugin harness.");
    }
}
