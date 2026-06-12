using System.Collections.ObjectModel;
using System.Diagnostics;
using System.Formats.Tar;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;

internal static class Program
{
    private const int HarnessTimeoutMs = 120_000;
    private const int MaxSerializedProcessOutputChars = 12_000;
    private const string SelectedCasesEnvVar = "GODOT_PLUGIN_HARNESS_SELECTED_CASES";
    private static readonly Regex SensitiveProcessOutputPattern = new(
        @"(?i)(authorization|bearer|token|access[_-]?token|refresh[_-]?token|api[_-]?key|secret|password|passwd|pwd)(\s*[:=]\s*)([^\s,;\]\}"" ]+|""[^""]*"")",
        RegexOptions.Compiled);
    private static readonly string[] LeakWarningMarkers =
    [
        "ObjectDB instances leaked at exit",
        "resources still in use at exit",
    ];
    private static readonly string[] RuntimeErrorMarkers =
    [
        "Invalid call.",
        "SCRIPT ERROR:",
        "Parse Error:",
        "Parser Error:",
        "Nonexistent function",
        "Attempt to call function",
    ];

    private static async Task<int> Main(string[] args)
    {
        Console.OutputEncoding = Encoding.UTF8;

        var repoRoot = ResolveRepoRoot();
        var allowSkipMissingGodot = args.Any(arg => string.Equals(arg, "--allow-skip-missing-godot", StringComparison.OrdinalIgnoreCase));
        var keepStageRoot = args.Any(arg => string.Equals(arg, "--keep-stage-root", StringComparison.OrdinalIgnoreCase));
        var listCases = args.Any(arg => string.Equals(arg, "--list-cases", StringComparison.OrdinalIgnoreCase));
        var cleanupStaleProcesses = args.Any(arg => string.Equals(arg, "--cleanup-stale-processes", StringComparison.OrdinalIgnoreCase));
        var cleanAssetLibraryInstallBuild = args.Any(arg => string.Equals(arg, "--clean-asset-library-install-build", StringComparison.OrdinalIgnoreCase));
        var onlyCase = Environment.GetEnvironmentVariable("GODOT_PLUGIN_HARNESS_ONLY_CASE");
        var selectedCases = ParseSelectedCases(GetOptionValue(args, "--cases")
            ?? Environment.GetEnvironmentVariable(SelectedCasesEnvVar));
        if (!string.IsNullOrWhiteSpace(onlyCase) && selectedCases.Length > 0)
        {
            Console.WriteLine(JsonSerializer.Serialize(new
            {
                success = false,
                skipped = false,
                reason = "only_case_and_selected_cases_conflict",
            }, new JsonSerializerOptions { WriteIndented = true }));
            return 1;
        }

        var explicitGodotPath = GetOptionValue(args, "--godot-path")
            ?? Environment.GetEnvironmentVariable("GODOT_BIN")
            ?? Environment.GetEnvironmentVariable("GODOT4_BIN");
        var editorProbeMode = string.Equals(onlyCase, "plugin_entrypoint_contracts", StringComparison.Ordinal)
            || string.Equals(onlyCase, "plugin_update_settings_persistence_contracts", StringComparison.Ordinal);

        if (cleanupStaleProcesses)
        {
            var cleanupResult = HarnessProcessRegistry.CleanupOrphanedEntries(repoRoot);
            Console.WriteLine(JsonSerializer.Serialize(cleanupResult, new JsonSerializerOptions { WriteIndented = true }));
            return 0;
        }

        HarnessProcessRegistry.CleanupOrphanedEntries(repoRoot);

        if (cleanAssetLibraryInstallBuild)
        {
            return await RunCleanAssetLibraryInstallBuildAsync(repoRoot, keepStageRoot);
        }

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
        var caseLabel = onlyCase ?? (selectedCases.Length > 0 ? $"selected-cases:{selectedCases.Length}" : (listCases ? "list-cases" : "all-cases"));
        using var processRegistry = HarnessProcessRegistry.Create(repoRoot, stageRoot, caseLabel);
        var phaseTimings = new List<PhaseTiming>();
        Process? process = null;
        Task<string>? stdoutTask = null;
        Task<string>? stderrTask = null;
        var preserveStageRoot = false;

        try
        {
            var copyStopwatch = Stopwatch.StartNew();
            CopyDirectory(Path.Combine(repoRoot, "tests", "godot_plugin_harness_fixture"), stageRoot);
            CopyDirectory(Path.Combine(repoRoot, "addons", "godot_dotnet_mcp"), Path.Combine(stageRoot, "addons", "godot_dotnet_mcp"));
            CopyContractCaseManifest(repoRoot, stageRoot);
            copyStopwatch.Stop();
            phaseTimings.Add(new PhaseTiming("copy_stage_inputs", copyStopwatch.ElapsedMilliseconds));
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

            var stageBuildStopwatch = Stopwatch.StartNew();
            var stageBuild = await BuildStageRootProject(stageRoot, processRegistry);
            stageBuildStopwatch.Stop();
            phaseTimings.Add(new PhaseTiming("build_stage_project", stageBuildStopwatch.ElapsedMilliseconds));
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
                    stdout = ToSerializedProcessOutput(stageBuild.StdOut),
                    stderr = ToSerializedProcessOutput(stageBuild.StdErr),
                    phaseTimings,
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
            process.StartInfo.Environment[SelectedCasesEnvVar] = string.Join(",", selectedCases);
            // Pre-set runtime environment variables for server_runtime_settings_projection test.
            // In Godot 4.3 headless mode, OS.has_environment() returns false for env vars
            // created via OS.set_environment() at runtime, even though OS.get_environment() works.
            // By pre-setting these in the parent process, they exist at Godot startup,
            // so has_environment() correctly returns true throughout the test.
            process.StartInfo.Environment["GODOT_DOTNET_MCP_SERVER_HOST"] = "10.0.0.8";
            process.StartInfo.Environment["GODOT_DOTNET_MCP_SERVER_PORT"] = "4100";
            process.StartInfo.Environment["GODOT_DOTNET_MCP_STDIO_FRAMING"] = "legacy_content_length";
            process.StartInfo.ArgumentList.Add("--headless");
            if (editorProbeMode)
            {
                process.StartInfo.ArgumentList.Add("--editor");
            }
            process.StartInfo.ArgumentList.Add("--path");
            process.StartInfo.ArgumentList.Add(stageRoot);

            var godotStopwatch = Stopwatch.StartNew();
            process.Start();
            processRegistry.Register(process, "godot-headless", explicitGodotPath, stageRoot, process.StartInfo.ArgumentList);
            stdoutTask = process.StandardOutput.ReadToEndAsync();
            stderrTask = process.StandardError.ReadToEndAsync();

            using var timeoutCts = new CancellationTokenSource(HarnessTimeoutMs);
            await process.WaitForExitAsync(timeoutCts.Token);
            godotStopwatch.Stop();
            phaseTimings.Add(new PhaseTiming("run_godot_process", godotStopwatch.ElapsedMilliseconds));

            var stdout = await stdoutTask;
            var stderr = await stderrTask;
            processRegistry.Unregister(process);

            if (listCases)
            {
                preserveStageRoot = keepStageRoot && process.ExitCode != 0;
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

            var suite = TryParseLastJsonLine(stdout);
            var suiteSuccess = TryGetJsonBooleanProperty(suite, "success");
            var exitCleanupWarningMarkers = CollectLeakWarningMarkers(stderr);
            var exitCleanupWarningsDetected = exitCleanupWarningMarkers.Length > 0;
            var exitCleanupWarningFailure = !editorProbeMode && exitCleanupWarningsDetected;
            var leakWarningsDetected = exitCleanupWarningFailure;
            var runtimeErrorMarkers = CollectRuntimeErrorMarkers(stdout, stderr);
            var runtimeErrorMarkersDetected = runtimeErrorMarkers.Length > 0;
            var failureClasses = new List<string>();
            if (runtimeErrorMarkersDetected)
            {
                failureClasses.Add("godot_runtime_error");
            }

            if (exitCleanupWarningFailure)
            {
                failureClasses.Add("exit_cleanup_warning");
            }

            var succeeded = process.ExitCode == 0 && failureClasses.Count == 0;
            preserveStageRoot = keepStageRoot && !succeeded;
            var primaryFailureClass = runtimeErrorMarkersDetected
                ? "godot_runtime_error"
                : (exitCleanupWarningFailure ? "exit_cleanup_warning" : string.Empty);
            var failureClass = primaryFailureClass;
            var reason = runtimeErrorMarkersDetected
                ? "godot_runtime_error_detected"
                : (exitCleanupWarningFailure ? "godot_exit_leaks_detected" : string.Empty);
            var summary = new
            {
                success = succeeded,
                skipped = false,
                exitCode = process.ExitCode,
                suiteSuccess,
                successMarkerDetected = suiteSuccess.HasValue,
                leakWarningsDetected,
                exitCleanupWarningFailure,
                exitCleanupWarningsDetected,
                exitCleanupWarningMarkers,
                exitCleanupWarningPolicy = exitCleanupWarningsDetected ? (editorProbeMode ? "ignored_editor_probe" : "fail_harness") : "none",
                runtimeErrorMarkersDetected,
                runtimeErrorMarkers,
                failureClasses,
                primaryFailureClass,
                failureClass,
                reason,
                godotPath = explicitGodotPath,
                stageRoot,
                stageKept = preserveStageRoot,
                suite,
                phaseTimings,
                stderr = ToSerializedProcessOutput(stderr),
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
                phaseTimings,
                stderr = ToSerializedProcessOutput(stderr),
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

    private static async Task<int> RunCleanAssetLibraryInstallBuildAsync(string repoRoot, bool keepStageRoot)
    {
        var stageRoot = Path.Combine(repoRoot, ".tmp", "godot_plugin_harness", Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(stageRoot);
        using var processRegistry = HarnessProcessRegistry.Create(repoRoot, stageRoot, "clean-asset-library-install-build");
        var phaseTimings = new List<PhaseTiming>();
        var preserveStageRoot = false;

        try
        {
            var copyStopwatch = Stopwatch.StartNew();
            CopyDirectory(Path.Combine(repoRoot, "tests", "godot_plugin_harness_fixture"), stageRoot);
            var archiveResult = await ExportAddonArchiveAsync(repoRoot, stageRoot, processRegistry);
            copyStopwatch.Stop();
            phaseTimings.Add(new PhaseTiming("copy_stage_inputs", copyStopwatch.ElapsedMilliseconds));

            if (!archiveResult.Succeeded)
            {
                preserveStageRoot = keepStageRoot;
                var archiveSummary = new
                {
                    success = false,
                    skipped = false,
                    reason = archiveResult.TimedOut ? "clean_asset_library_archive_timeout" : "clean_asset_library_archive_failed",
                    exitCode = archiveResult.ExitCode,
                    stageRoot,
                    stageKept = preserveStageRoot,
                    stdout = ToSerializedProcessOutput(archiveResult.StdOut),
                    stderr = ToSerializedProcessOutput(archiveResult.StdErr),
                    phaseTimings,
                };
                Console.WriteLine(JsonSerializer.Serialize(archiveSummary, new JsonSerializerOptions { WriteIndented = true }));
                return 1;
            }

            DeleteDirectoryIfExists(Path.Combine(stageRoot, ".godot"));
            RemoveRoslynPackageReference(Path.Combine(stageRoot, "GodotDotnetMcpPluginHarness.csproj"));

            var fixtureHasRoslynPackageReference = FileContainsText(
                Path.Combine(stageRoot, "GodotDotnetMcpPluginHarness.csproj"),
                "Microsoft.CodeAnalysis.CSharp");
            var exportedRoslynRuntimeSources = HasExportedSourceFiles(Path.Combine(stageRoot, "addons", "godot_dotnet_mcp", "plugin", "runtime", "roslyn"));
            var exportedDotnetBridgeSources = HasExportedSourceFiles(Path.Combine(stageRoot, "addons", "godot_dotnet_mcp", "dotnet_bridge"));
            var exportedRoslynRuntimeManifest = File.Exists(Path.Combine(
                stageRoot,
                "addons",
                "godot_dotnet_mcp",
                "plugin",
                "runtime",
                "roslyn_runtime",
                "roslyn-runtime-manifest.json"));
            var missingRoslynRuntimeManifestFiles = exportedRoslynRuntimeManifest
                ? GetMissingRoslynRuntimeManifestFiles(stageRoot)
                : [];
            var exportedRoslynRuntimeExecutable = HasRoslynRuntimeExecutable(Path.Combine(
                stageRoot,
                "addons",
                "godot_dotnet_mcp",
                "plugin",
                "runtime",
                "roslyn_runtime"));

            var stageBuildStopwatch = Stopwatch.StartNew();
            var stageBuild = await BuildStageRootProject(stageRoot, processRegistry);
            stageBuildStopwatch.Stop();
            phaseTimings.Add(new PhaseTiming("build_stage_project", stageBuildStopwatch.ElapsedMilliseconds));
            var runtimeProbeStopwatch = Stopwatch.StartNew();
            var runtimeProbe = exportedRoslynRuntimeExecutable
                ? await ProbeExportedRoslynRuntimeAsync(stageRoot, processRegistry)
                : (Succeeded: false, ExitCode: -1, StdOut: string.Empty, StdErr: "Roslyn runtime executable missing.", TimedOut: false);
            runtimeProbeStopwatch.Stop();
            phaseTimings.Add(new PhaseTiming("probe_exported_roslyn_runtime", runtimeProbeStopwatch.ElapsedMilliseconds));

            var succeeded = stageBuild.Succeeded
                && !fixtureHasRoslynPackageReference
                && !exportedRoslynRuntimeSources
                && !exportedDotnetBridgeSources
                && exportedRoslynRuntimeManifest
                && missingRoslynRuntimeManifestFiles.Length == 0
                && exportedRoslynRuntimeExecutable
                && runtimeProbe.Succeeded;
            preserveStageRoot = keepStageRoot && !succeeded;
            var summary = new
            {
                success = succeeded,
                skipped = false,
                reason = succeeded ? string.Empty : (stageBuild.TimedOut ? "clean_asset_library_install_build_timeout" : "clean_asset_library_install_build_failed"),
                exitCode = stageBuild.ExitCode,
                exportedWithGitArchive = true,
                stageRoot,
                stageKept = preserveStageRoot,
                fixtureHasRoslynPackageReference,
                exportedRoslynRuntimeSources,
                exportedDotnetBridgeSources,
                exportedRoslynRuntimeManifest,
                missingRoslynRuntimeManifestFiles,
                exportedRoslynRuntimeExecutable,
                exportedRoslynRuntimeProbeSucceeded = runtimeProbe.Succeeded,
                exportedRoslynRuntimeProbeExitCode = runtimeProbe.ExitCode,
                exportedRoslynRuntimeProbeTimedOut = runtimeProbe.TimedOut,
                exportedRoslynRuntimeProbeStdout = ToSerializedProcessOutput(runtimeProbe.StdOut),
                exportedRoslynRuntimeProbeStderr = ToSerializedProcessOutput(runtimeProbe.StdErr),
                stdout = ToSerializedProcessOutput(stageBuild.StdOut),
                stderr = ToSerializedProcessOutput(stageBuild.StdErr),
                phaseTimings,
            };
            Console.WriteLine(JsonSerializer.Serialize(summary, new JsonSerializerOptions { WriteIndented = true }));
            return succeeded ? 0 : 1;
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

    private static async Task<(bool Succeeded, int ExitCode, string StdOut, string StdErr, bool TimedOut)> ExportAddonArchiveAsync(string repoRoot, string stageRoot, HarnessProcessRegistry processRegistry)
    {
        var archivePath = Path.Combine(stageRoot, "asset-library-addon.tar");
        Process? process = null;
        Task<string>? stderrTask = null;
        FileStream? archiveStream = null;

        try
        {
            archiveStream = File.Create(archivePath);
            process = new Process
            {
                StartInfo = new ProcessStartInfo("git")
                {
                    WorkingDirectory = repoRoot,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    UseShellExecute = false,
                    CreateNoWindow = true,
                }
            };
            process.StartInfo.ArgumentList.Add("archive");
            process.StartInfo.ArgumentList.Add("--format=tar");
            process.StartInfo.ArgumentList.Add("--worktree-attributes");
            process.StartInfo.ArgumentList.Add("HEAD");
            process.StartInfo.ArgumentList.Add("addons/godot_dotnet_mcp");
            process.Start();
            processRegistry.Register(process, "git-archive", "git", repoRoot, process.StartInfo.ArgumentList);
            var stdoutTask = process.StandardOutput.BaseStream.CopyToAsync(archiveStream);
            stderrTask = process.StandardError.ReadToEndAsync();

            using var timeoutCts = new CancellationTokenSource(HarnessTimeoutMs);
            await process.WaitForExitAsync(timeoutCts.Token);
            await stdoutTask;
            await archiveStream.DisposeAsync();
            archiveStream = null;

            var stderr = await TryReadOutputAsync(stderrTask);
            processRegistry.Unregister(process);
            if (process.ExitCode != 0)
            {
                return (false, process.ExitCode, string.Empty, stderr, false);
            }

            TarFile.ExtractToDirectory(archivePath, stageRoot, overwriteFiles: true);
            File.Delete(archivePath);
            return (true, process.ExitCode, string.Empty, stderr, false);
        }
        catch (OperationCanceledException)
        {
            TryKillProcessTree(process);
            var stderr = await TryReadOutputAsync(stderrTask);
            processRegistry.Unregister(process);
            return (false, -1, string.Empty, stderr, true);
        }
        finally
        {
            if (archiveStream is not null)
            {
                await archiveStream.DisposeAsync();
            }
        }
    }

    private static string[] ParseSelectedCases(string? rawCases)
    {
        if (string.IsNullOrWhiteSpace(rawCases))
        {
            return [];
        }

        return rawCases
            .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Where(static item => !string.IsNullOrWhiteSpace(item))
            .Distinct(StringComparer.Ordinal)
            .ToArray();
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

    private static string ToSerializedProcessOutput(string output)
    {
        if (string.IsNullOrWhiteSpace(output))
        {
            return string.Empty;
        }

        var redacted = SensitiveProcessOutputPattern.Replace(output.Trim(), "$1$2[redacted]");
        if (redacted.Length <= MaxSerializedProcessOutputChars)
        {
            return redacted;
        }

        return string.Concat(
            redacted.AsSpan(0, MaxSerializedProcessOutputChars),
            Environment.NewLine,
            $"[truncated {redacted.Length - MaxSerializedProcessOutputChars} chars]");
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
                    WorkingDirectory = Path.GetTempPath(),
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    UseShellExecute = false,
                    CreateNoWindow = true,
                }
            };
            process.StartInfo.ArgumentList.Add("build");
            process.StartInfo.ArgumentList.Add(Path.Combine(stageRoot, "GodotDotnetMcpPluginHarness.csproj"));
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

    private static void RemoveRoslynPackageReference(string projectFilePath)
    {
        if (!File.Exists(projectFilePath))
        {
            return;
        }

        var lines = File.ReadAllLines(projectFilePath);
        var filteredLines = lines
            .Where(line => !line.Contains("Microsoft.CodeAnalysis.CSharp", StringComparison.Ordinal))
            .ToArray();
        File.WriteAllLines(projectFilePath, filteredLines, Encoding.UTF8);
    }

    private static bool FileContainsText(string path, string text)
    {
        return File.Exists(path) && File.ReadAllText(path).Contains(text, StringComparison.Ordinal);
    }

    private static bool HasExportedSourceFiles(string directoryPath)
    {
        if (!Directory.Exists(directoryPath))
        {
            return false;
        }

        return Directory.EnumerateFiles(directoryPath, "*", SearchOption.AllDirectories)
            .Any(path => path.EndsWith(".cs", StringComparison.OrdinalIgnoreCase)
                || path.EndsWith(".csproj", StringComparison.OrdinalIgnoreCase));
    }

    private static bool HasRoslynRuntimeExecutable(string directoryPath)
    {
        if (!Directory.Exists(directoryPath))
        {
            return false;
        }

        return Directory.EnumerateFiles(directoryPath, "GodotDotnetMcp.PluginBridge.*", SearchOption.TopDirectoryOnly)
            .Any(path => path.EndsWith(".dll", StringComparison.OrdinalIgnoreCase)
                || path.EndsWith(".exe", StringComparison.OrdinalIgnoreCase));
    }

    private static string[] GetMissingRoslynRuntimeManifestFiles(string stageRoot)
    {
        var runtimeDirectory = Path.Combine(
            stageRoot,
            "addons",
            "godot_dotnet_mcp",
            "plugin",
            "runtime",
            "roslyn_runtime");
        var manifestPath = Path.Combine(runtimeDirectory, "roslyn-runtime-manifest.json");
        try
        {
            using var document = JsonDocument.Parse(File.ReadAllText(manifestPath));
            if (!document.RootElement.TryGetProperty("files", out var filesElement) ||
                filesElement.ValueKind != JsonValueKind.Array)
            {
                return ["roslyn-runtime-manifest.json:files"];
            }

            var missing = new List<string>();
            foreach (var fileElement in filesElement.EnumerateArray())
            {
                if (fileElement.ValueKind != JsonValueKind.String)
                {
                    missing.Add("roslyn-runtime-manifest.json:non_string_file_entry");
                    continue;
                }

                var fileName = fileElement.GetString();
                if (string.IsNullOrWhiteSpace(fileName))
                {
                    missing.Add("roslyn-runtime-manifest.json:empty_file_entry");
                    continue;
                }

                if (!File.Exists(Path.Combine(runtimeDirectory, fileName)))
                {
                    missing.Add(fileName);
                }
            }

            return missing.ToArray();
        }
        catch (Exception ex)
        {
            return [$"roslyn-runtime-manifest.json:{ex.GetType().Name}"];
        }
    }

    private static async Task<(bool Succeeded, int ExitCode, string StdOut, string StdErr, bool TimedOut)> ProbeExportedRoslynRuntimeAsync(string stageRoot, HarnessProcessRegistry processRegistry)
    {
        var runtimeDll = Path.Combine(
            stageRoot,
            "addons",
            "godot_dotnet_mcp",
            "plugin",
            "runtime",
            "roslyn_runtime",
            "GodotDotnetMcp.PluginBridge.dll");
        if (!File.Exists(runtimeDll))
        {
            return (false, -1, string.Empty, "GodotDotnetMcp.PluginBridge.dll is missing from the exported runtime bundle.", false);
        }

        var probePath = Path.Combine(stageRoot, "RoslynRuntimeProbe.cs");
        var requestPath = Path.Combine(stageRoot, "roslyn-runtime-probe-request.json");
        await File.WriteAllTextAsync(probePath, "public partial class RoslynRuntimeProbe { [Export] public int Speed = 1; public void Run() { } }", Encoding.UTF8);
        await File.WriteAllTextAsync(requestPath, JsonSerializer.Serialize(new
        {
            path = "res://RoslynRuntimeProbe.cs",
            action = "upsert_method",
            type_name = "RoslynRuntimeProbe",
            member_name = "AddedByRuntimeProbe",
            return_type = "int",
            parameters = Array.Empty<string>(),
            body = "return 1;",
        }), Encoding.UTF8);

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
            process.StartInfo.Environment["GODOT_DOTNET_MCP_PROJECT_ROOT"] = stageRoot;
            process.StartInfo.ArgumentList.Add(runtimeDll);
            process.StartInfo.ArgumentList.Add("--call-json-file");
            process.StartInfo.ArgumentList.Add("cs_plugin_patch");
            process.StartInfo.ArgumentList.Add(requestPath);
            process.Start();
            processRegistry.Register(process, "roslyn-runtime-probe", "dotnet", stageRoot, process.StartInfo.ArgumentList);
            stdoutTask = process.StandardOutput.ReadToEndAsync();
            stderrTask = process.StandardError.ReadToEndAsync();

            using var timeoutCts = new CancellationTokenSource(HarnessTimeoutMs);
            await process.WaitForExitAsync(timeoutCts.Token);
            var stdout = await TryReadOutputAsync(stdoutTask);
            var stderr = await TryReadOutputAsync(stderrTask);
            processRegistry.Unregister(process);
            return (
                process.ExitCode == 0
                    && stdout.Contains("\"success\":true", StringComparison.Ordinal)
                    && stdout.Contains("\"semanticRuntime\":\"Roslyn\"", StringComparison.Ordinal)
                    && stdout.Contains("\"action\":\"upsert_method\"", StringComparison.Ordinal)
                    && stdout.Contains("\"name\":\"Speed\"", StringComparison.Ordinal),
                process.ExitCode,
                stdout,
                stderr,
                false);
        }
        catch (OperationCanceledException)
        {
            TryKillProcessTree(process);
            var stdout = await TryReadOutputAsync(stdoutTask);
            var stderr = await TryReadOutputAsync(stderrTask);
            processRegistry.Unregister(process);
            return (false, -1, stdout, stderr, true);
        }
        catch (Exception ex)
        {
            return (false, -1, string.Empty, ex.ToString(), false);
        }
        finally
        {
            process?.Dispose();
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

    private static void CopyContractCaseManifest(string repoRoot, string stageRoot)
    {
        var sourcePath = Path.Combine(repoRoot, "scripts", "contract_case_manifest.json");
        if (!File.Exists(sourcePath))
        {
            return;
        }

        var destinationDirectory = Path.Combine(stageRoot, "scripts");
        Directory.CreateDirectory(destinationDirectory);
        File.Copy(sourcePath, Path.Combine(destinationDirectory, "contract_case_manifest.json"), overwrite: true);
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

    private static string[] CollectLeakWarningMarkers(string stderr)
    {
        if (string.IsNullOrWhiteSpace(stderr))
        {
            return [];
        }

        return LeakWarningMarkers
            .Where(marker => stderr.Contains(marker, StringComparison.Ordinal))
            .ToArray();
    }

    private static string[] CollectRuntimeErrorMarkers(string stdout, string stderr)
    {
        var combinedOutput = string.Concat(stdout ?? string.Empty, "\n", stderr ?? string.Empty);
        if (string.IsNullOrWhiteSpace(combinedOutput))
        {
            return [];
        }

        return RuntimeErrorMarkers
            .Where(marker => combinedOutput.Contains(marker, StringComparison.Ordinal))
            .ToArray();
    }

    private static bool? TryGetJsonBooleanProperty(object? json, string propertyName)
    {
        if (json is not JsonElement element || element.ValueKind != JsonValueKind.Object)
        {
            return null;
        }

        if (!element.TryGetProperty(propertyName, out var property) || property.ValueKind is not JsonValueKind.True and not JsonValueKind.False)
        {
            return null;
        }

        return property.GetBoolean();
    }

    private sealed record PhaseTiming(string Name, long DurationMs);

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
