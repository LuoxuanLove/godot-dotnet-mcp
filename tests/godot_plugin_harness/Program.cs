using System.Collections.ObjectModel;
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
        var cleanupStaleProcesses = args.Any(arg => string.Equals(arg, "--cleanup-stale-processes", StringComparison.OrdinalIgnoreCase));
        var onlyCase = Environment.GetEnvironmentVariable("GODOT_PLUGIN_HARNESS_ONLY_CASE");
        var explicitGodotPath = GetOptionValue(args, "--godot-path")
            ?? Environment.GetEnvironmentVariable("GODOT_BIN")
            ?? Environment.GetEnvironmentVariable("GODOT4_BIN");
        var editorProbeMode = string.Equals(onlyCase, "plugin_entrypoint_contracts", StringComparison.Ordinal);

        if (cleanupStaleProcesses)
        {
            var cleanupResult = HarnessProcessRegistry.CleanupOrphanedEntries(repoRoot);
            Console.WriteLine(JsonSerializer.Serialize(cleanupResult, new JsonSerializerOptions { WriteIndented = true }));
            return 0;
        }

        HarnessProcessRegistry.CleanupOrphanedEntries(repoRoot);

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
        using var processRegistry = HarnessProcessRegistry.Create(repoRoot, stageRoot, onlyCase ?? (listCases ? "list-cases" : "all-cases"));
        Process? process = null;
        Task<string>? stdoutTask = null;
        Task<string>? stderrTask = null;
        var preserveStageRoot = false;

        try
        {
            CopyDirectory(Path.Combine(repoRoot, "tests", "godot_plugin_harness_fixture"), stageRoot);
            CopyDirectory(Path.Combine(repoRoot, "addons", "godot_dotnet_mcp"), Path.Combine(stageRoot, "addons", "godot_dotnet_mcp"));
            if (editorProbeMode)
            {
                DisableProductionPluginForEditorProbe(stageRoot);
            }
            DeleteDirectoryIfExists(Path.Combine(stageRoot, ".godot"));
            DeleteDirectoryIfExists(Path.Combine(stageRoot, "addons", "godot_dotnet_mcp", "dotnet_bridge"));
            var appDataRoot = Path.Combine(stageRoot, ".appdata");
            var localAppDataRoot = Path.Combine(stageRoot, ".localappdata");
            Directory.CreateDirectory(appDataRoot);
            Directory.CreateDirectory(localAppDataRoot);

            var stageBuild = await BuildStageRootProject(stageRoot, processRegistry);
            if (!stageBuild.Succeeded)
            {
                preserveStageRoot = keepStageRoot;
                var buildSummary = new
                {
                    success = false,
                    skipped = false,
                    reason = stageBuild.TimedOut ? "stage_root_csharp_build_timeout" : "stage_root_csharp_build_failed",
                    exitCode = stageBuild.ExitCode,
                    godotPath = explicitGodotPath,
                    stageRoot,
                    stageKept = preserveStageRoot,
                    stdout = string.IsNullOrWhiteSpace(stageBuild.StdOut) ? string.Empty : stageBuild.StdOut.Trim(),
                    stderr = string.IsNullOrWhiteSpace(stageBuild.StdErr) ? string.Empty : stageBuild.StdErr.Trim(),
                };
                Console.WriteLine(JsonSerializer.Serialize(buildSummary, new JsonSerializerOptions { WriteIndented = true }));
                return 1;
            }

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
            if (editorProbeMode)
            {
                process.StartInfo.ArgumentList.Add("--editor");
            }
            process.StartInfo.ArgumentList.Add("--path");
            process.StartInfo.ArgumentList.Add(stageRoot);

            process.Start();
            processRegistry.Register(process, "godot-headless", explicitGodotPath, stageRoot, process.StartInfo.ArgumentList);
            stdoutTask = process.StandardOutput.ReadToEndAsync();
            stderrTask = process.StandardError.ReadToEndAsync();

            using var timeoutCts = new CancellationTokenSource(HarnessTimeoutMs);
            await process.WaitForExitAsync(timeoutCts.Token);

            var stdout = await stdoutTask;
            var stderr = await stderrTask;
            processRegistry.Unregister(process);

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

            var leakWarningsDetected = editorProbeMode ? false : ContainsLeakWarnings(stderr);
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
            processRegistry.Unregister(process);
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
                processRegistryPath = processRegistry.EntryPath,
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

    private static async Task<(bool Succeeded, int ExitCode, string StdOut, string StdErr, bool TimedOut)> BuildStageRootProject(string stageRoot, HarnessProcessRegistry processRegistry)
    {
        Process? process = null;
        Task<string>? stdoutTask = null;
        Task<string>? stderrTask = null;

        try
        {
            process = new Process
            {
                StartInfo = new ProcessStartInfo("dotnet")
                {
                    WorkingDirectory = stageRoot,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    UseShellExecute = false,
                    CreateNoWindow = true,
                }
            };
            process.StartInfo.ArgumentList.Add("build");
            process.StartInfo.ArgumentList.Add("GodotDotnetMcpPluginHarness.csproj");
            process.StartInfo.ArgumentList.Add("-c");
            process.StartInfo.ArgumentList.Add("Debug");
            process.StartInfo.ArgumentList.Add("--nologo");
            process.Start();
            processRegistry.Register(process, "dotnet-build", "dotnet", stageRoot, process.StartInfo.ArgumentList);
            stdoutTask = process.StandardOutput.ReadToEndAsync();
            stderrTask = process.StandardError.ReadToEndAsync();

            using var timeoutCts = new CancellationTokenSource(HarnessTimeoutMs);
            await process.WaitForExitAsync(timeoutCts.Token);

            var stdout = await TryReadOutputAsync(stdoutTask);
            var stderr = await TryReadOutputAsync(stderrTask);
            processRegistry.Unregister(process);
            return (process.ExitCode == 0, process.ExitCode, stdout, stderr, false);
        }
        catch (OperationCanceledException)
        {
            TryKillProcessTree(process);
            var stdout = await TryReadOutputAsync(stdoutTask);
            var stderr = await TryReadOutputAsync(stderrTask);
            processRegistry.Unregister(process);
            return (false, -1, stdout, stderr, true);
        }
    }

    private static void DeleteDirectoryIfExists(string path)
    {
        if (!Directory.Exists(path))
        {
            return;
        }

        Directory.Delete(path, recursive: true);
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

    private static void DisableProductionPluginForEditorProbe(string stageRoot)
    {
        var projectFilePath = Path.Combine(stageRoot, "project.godot");
        if (!File.Exists(projectFilePath))
        {
            return;
        }

        var lines = File.ReadAllLines(projectFilePath).ToList();
        for (var index = 0; index < lines.Count; index++)
        {
            if (!lines[index].StartsWith("enabled=PackedStringArray(", StringComparison.Ordinal))
            {
                continue;
            }

            lines[index] = "enabled=PackedStringArray(\"res://addons/godot_plugin_harness_probe/plugin.cfg\")";
            break;
        }

        File.WriteAllLines(projectFilePath, lines);
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
                && Directory.Exists(Path.Combine(current.FullName, "tests", "godot_plugin_harness_fixture")))
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

    private sealed class HarnessProcessRegistry : IDisposable
    {
        private static readonly JsonSerializerOptions JsonOptions = new() { WriteIndented = true };
        private readonly string _repoRoot;
        private readonly string _stageRoot;
        private readonly string _runId;
        private readonly string _caseName;
        private readonly List<HarnessRegisteredProcess> _children = [];
        private bool _disposed;

        private HarnessProcessRegistry(string repoRoot, string stageRoot, string caseName)
        {
            _repoRoot = Path.GetFullPath(repoRoot);
            _stageRoot = Path.GetFullPath(stageRoot);
            _caseName = caseName;
            _runId = Path.GetFileName(_stageRoot);
            EntryPath = Path.Combine(GetRegistryRoot(_repoRoot), _runId + ".json");
            Directory.CreateDirectory(Path.GetDirectoryName(EntryPath)!);
            WriteSnapshot();
        }

        public string EntryPath { get; }

        public static HarnessProcessRegistry Create(string repoRoot, string stageRoot, string caseName)
        {
            return new HarnessProcessRegistry(repoRoot, stageRoot, caseName);
        }

        public static object CleanupOrphanedEntries(string repoRoot)
        {
            var registryRoot = GetRegistryRoot(Path.GetFullPath(repoRoot));
            var scanned = 0;
            var removedEntries = 0;
            var killedProcesses = 0;
            var warnings = new List<string>();
            if (!Directory.Exists(registryRoot))
            {
                return new
                {
                    success = true,
                    action = "cleanup_stale_processes",
                    registryRoot,
                    scanned,
                    removedEntries,
                    killedProcesses,
                    warnings,
                };
            }

            foreach (var entryPath in Directory.EnumerateFiles(registryRoot, "*.json", SearchOption.TopDirectoryOnly))
            {
                scanned++;
                try
                {
                    var entry = JsonSerializer.Deserialize<HarnessProcessRegistryEntry>(File.ReadAllText(entryPath));
                    if (entry is null || !IsHarnessStageRoot(repoRoot, entry.StageRoot))
                    {
                        warnings.Add($"Skipped invalid registry entry: {entryPath}");
                        continue;
                    }

                    if (IsProcessAlive(entry.OwnerPid))
                    {
                        continue;
                    }

                    foreach (var child in entry.Children)
                    {
                        if (TryKillRegisteredProcess(child))
                        {
                            killedProcesses++;
                        }
                    }

                    File.Delete(entryPath);
                    removedEntries++;
                }
                catch (Exception ex)
                {
                    warnings.Add($"Failed to process registry entry '{entryPath}': {ex.Message}");
                }
            }

            return new
            {
                success = true,
                action = "cleanup_stale_processes",
                registryRoot,
                scanned,
                removedEntries,
                killedProcesses,
                warnings,
            };
        }

        public void Register(Process process, string kind, string executablePath, string workingDirectory, Collection<string> arguments)
        {
            if (_disposed || process.HasExited)
            {
                return;
            }

            var child = new HarnessRegisteredProcess
            {
                Pid = process.Id,
                Kind = kind,
                ExecutablePath = executablePath,
                WorkingDirectory = Path.GetFullPath(workingDirectory),
                CommandLineHint = BuildCommandLineHint(executablePath, arguments),
                StartedAtUtc = TryGetProcessStartTimeUtc(process),
            };
            _children.RemoveAll(existing => existing.Pid == child.Pid);
            _children.Add(child);
            WriteSnapshot();
        }

        public void Unregister(Process? process)
        {
            if (process is null || _disposed)
            {
                return;
            }

            _children.RemoveAll(child => child.Pid == process.Id);
            WriteSnapshot();
        }

        public void Dispose()
        {
            if (_disposed)
            {
                return;
            }

            _disposed = true;
            try
            {
                if (File.Exists(EntryPath))
                {
                    File.Delete(EntryPath);
                }
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"[harness] Failed to delete process registry entry '{EntryPath}': {ex.Message}");
            }
        }

        private static string GetRegistryRoot(string repoRoot)
        {
            return Path.Combine(repoRoot, ".tmp", "godot_plugin_harness", "processes");
        }

        private static bool IsHarnessStageRoot(string repoRoot, string stageRoot)
        {
            if (string.IsNullOrWhiteSpace(stageRoot))
            {
                return false;
            }

            var harnessRoot = Path.GetFullPath(Path.Combine(repoRoot, ".tmp", "godot_plugin_harness"));
            var resolvedStageRoot = Path.GetFullPath(stageRoot);
            var normalizedHarnessRoot = harnessRoot.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar) + Path.DirectorySeparatorChar;
            return resolvedStageRoot.StartsWith(normalizedHarnessRoot, StringComparison.OrdinalIgnoreCase)
                && !resolvedStageRoot.StartsWith(GetRegistryRoot(Path.GetFullPath(repoRoot)), StringComparison.OrdinalIgnoreCase);
        }

        private static bool IsProcessAlive(int pid)
        {
            try
            {
                using var process = Process.GetProcessById(pid);
                return !process.HasExited;
            }
            catch (ArgumentException)
            {
                return false;
            }
            catch (InvalidOperationException)
            {
                return false;
            }
        }

        private static bool TryKillRegisteredProcess(HarnessRegisteredProcess child)
        {
            try
            {
                using var process = Process.GetProcessById(child.Pid);
                if (process.HasExited || !ProcessStartMatches(process, child.StartedAtUtc))
                {
                    return false;
                }

                process.Kill(entireProcessTree: true);
                process.WaitForExit(5_000);
                return true;
            }
            catch (ArgumentException)
            {
                return false;
            }
            catch (InvalidOperationException)
            {
                return false;
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"[harness] Failed to kill registered process {child.Pid}: {ex.Message}");
                return false;
            }
        }

        private static bool ProcessStartMatches(Process process, DateTimeOffset registeredStart)
        {
            try
            {
                var actualStart = new DateTimeOffset(process.StartTime.ToUniversalTime(), TimeSpan.Zero);
                return Math.Abs((actualStart - registeredStart).TotalSeconds) <= 10;
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"[harness] Failed to verify process start time for {process.Id}: {ex.Message}");
                return false;
            }
        }

        private static DateTimeOffset TryGetProcessStartTimeUtc(Process process)
        {
            try
            {
                return new DateTimeOffset(process.StartTime.ToUniversalTime(), TimeSpan.Zero);
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"[harness] Failed to read process start time for {process.Id}: {ex.Message}");
                return DateTimeOffset.UtcNow;
            }
        }

        private static string BuildCommandLineHint(string executablePath, Collection<string> arguments)
        {
            var parts = new List<string> { QuoteArgument(executablePath) };
            foreach (var argument in arguments)
            {
                parts.Add(QuoteArgument(argument));
            }

            return string.Join(" ", parts);
        }

        private static string QuoteArgument(string value)
        {
            if (string.IsNullOrEmpty(value))
            {
                return "\"\"";
            }

            return value.Any(char.IsWhiteSpace) ? "\"" + value.Replace("\"", "\\\"", StringComparison.Ordinal) + "\"" : value;
        }

        private void WriteSnapshot()
        {
            if (_disposed)
            {
                return;
            }

            var entry = new HarnessProcessRegistryEntry
            {
                RunId = _runId,
                CaseName = _caseName,
                RepoRoot = _repoRoot,
                StageRoot = _stageRoot,
                OwnerPid = Environment.ProcessId,
                StartedAtUtc = DateTimeOffset.UtcNow,
                Children = [.. _children],
            };
            File.WriteAllText(EntryPath, JsonSerializer.Serialize(entry, JsonOptions), Encoding.UTF8);
        }
    }

    private sealed class HarnessProcessRegistryEntry
    {
        public string RunId { get; set; } = string.Empty;
        public string CaseName { get; set; } = string.Empty;
        public string RepoRoot { get; set; } = string.Empty;
        public string StageRoot { get; set; } = string.Empty;
        public int OwnerPid { get; set; }
        public DateTimeOffset StartedAtUtc { get; set; }
        public List<HarnessRegisteredProcess> Children { get; set; } = [];
    }

    private sealed class HarnessRegisteredProcess
    {
        public int Pid { get; set; }
        public string Kind { get; set; } = string.Empty;
        public string ExecutablePath { get; set; } = string.Empty;
        public string WorkingDirectory { get; set; } = string.Empty;
        public string CommandLineHint { get; set; } = string.Empty;
        public DateTimeOffset StartedAtUtc { get; set; }
    }
}
