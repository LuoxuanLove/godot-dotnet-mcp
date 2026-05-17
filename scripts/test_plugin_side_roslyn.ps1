param(
    [string]$GodotPath
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

. (Join-Path $repoRoot "scripts\dotnet_build_failure_diagnostics.ps1")

function Format-Duration {
    param(
        [TimeSpan]$Duration
    )

    return "{0:n1}s" -f $Duration.TotalSeconds
}

function New-TimingRecord {
    param(
        [string]$Name,
        [TimeSpan]$Duration
    )

    return [pscustomobject]@{
        Name = $Name
        Duration = $Duration
    }
}

function Write-HarnessTimingSummary {
    param(
        [object[]]$Timings,
        [TimeSpan]$TotalDuration
    )

    Write-Host ""
    Write-Host "Harness timing summary:"
    Write-Host "  Total: $(Format-Duration -Duration $TotalDuration)"
    foreach ($timing in $Timings) {
        Write-Host "  - $($timing.Name): $(Format-Duration -Duration $timing.Duration)"
    }

    if ([string]::IsNullOrWhiteSpace($env:GITHUB_STEP_SUMMARY)) {
        return
    }

    try {
        $summaryLines = @(
            "### Plugin harness timing"
            ""
            "Total duration: $(Format-Duration -Duration $TotalDuration)"
            ""
            "| Stage | Duration |"
            "| --- | ---: |"
        )

        foreach ($timing in $Timings) {
            $summaryLines += "| $($timing.Name) | $(Format-Duration -Duration $timing.Duration) |"
        }

        Add-Content -LiteralPath $env:GITHUB_STEP_SUMMARY -Value $summaryLines -Encoding UTF8
    }
    catch {
        Write-Warning "Unable to write GitHub Step Summary: $($_.Exception.Message)"
    }
}

function Resolve-GodotPath {
    param(
        [string]$GodotPath
    )

    $candidates = @($GodotPath, $env:GODOT_BIN, $env:GODOT4_BIN) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    throw "Godot executable not found. Pass -GodotPath or set GODOT_BIN/GODOT4_BIN."
}

function Invoke-CommandOrThrow {
    param(
        [string]$Description,
        [scriptblock]$Command
    )

    Write-Host "==> $Description"
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        & $Command
        if ($LASTEXITCODE -ne 0) {
            throw "$Description failed with exit code $LASTEXITCODE."
        }
    }
    finally {
        $stopwatch.Stop()
        Write-Host "==> $Description completed in $(Format-Duration -Duration $stopwatch.Elapsed)"
    }

    return New-TimingRecord -Name $Description -Duration $stopwatch.Elapsed
}

function Get-LastJsonObject {
    param(
        [string[]]$Lines,
        [string]$Description
    )

    for ($index = $Lines.Count - 1; $index -ge 0; $index--) {
        $candidate = $Lines[$index].Trim()
        if (-not $candidate.StartsWith("{")) {
            continue
        }

        try {
            $jsonText = ($Lines[$index..($Lines.Count - 1)] -join [Environment]::NewLine).Trim()
            return $jsonText | ConvertFrom-Json
        }
        catch {
            continue
        }
    }

    throw "Unable to parse JSON output for $Description."
}

function Invoke-Harness {
    param(
        [string]$Description,
        [string[]]$ExtraArgs
    )

    $arguments = @(
        "run"
        "--project"
        ".\tests\godot_plugin_harness\GodotPluginHarness.csproj"
        "-c"
        "Release"
        "--"
        "--godot-path"
        $GodotExe
    ) + $ExtraArgs

    Write-Host "==> $Description"
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $outputLines = & dotnet @arguments 2>&1 | ForEach-Object { $_.ToString() }
        $exitCode = $LASTEXITCODE
        $outputText = ($outputLines -join [Environment]::NewLine).Trim()
        $json = $null
        if ($outputLines.Count -gt 0) {
            $json = Get-LastJsonObject -Lines $outputLines -Description $Description
        }

        if ($exitCode -ne 0) {
            $details = if ([string]::IsNullOrWhiteSpace($outputText)) { "<no output>" } else { $outputText }
            throw "$Description failed with exit code $exitCode.`n$details"
        }

        if ($json -ne $null -and ($json.PSObject.Properties.Name -contains "success") -and -not [bool]$json.success) {
            throw "$Description reported success=false.`n$($outputText)"
        }
    }
    finally {
        $stopwatch.Stop()
        Write-Host "==> $Description completed in $(Format-Duration -Duration $stopwatch.Elapsed)"
    }

    return [pscustomobject]@{
        ExitCode = $exitCode
        Json = $json
        Output = $outputText
        Duration = $stopwatch.Elapsed
    }
}

function Remove-IfExists {
    param(
        [string]$Path
    )

    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Recurse -Force
    }
}

function Invoke-HarnessProcessCleanup {
    Write-Host "==> Cleanup stale harness-owned processes"
    $arguments = @(
        "run"
        "--project"
        ".\tests\godot_plugin_harness\GodotPluginHarness.csproj"
        "-c"
        "Release"
        "--"
        "--cleanup-stale-processes"
    )

    try {
        & dotnet @arguments 2>&1 | ForEach-Object { Write-Host $_.ToString() }
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Harness-owned process cleanup exited with code $LASTEXITCODE. Directory cleanup will continue."
        }
    }
    catch {
        Write-Warning "Harness-owned process cleanup failed: $($_.Exception.Message)"
    }
}

$GodotExe = Resolve-GodotPath -GodotPath $GodotPath
$RequiredCases = @(
    "plugin_roslyn_service_contracts"
    "roslyn_parsing_contracts"
    "csharp_tool_engine_contracts"
    "plugin_path_csharp_registration_probe"
    "system_editor_state_contracts"
    "system_editor_log_contracts"
    "system_runtime_health_contracts"
    "system_plugin_reload_contracts"
    "system_runtime_impl_contracts"
    "http_server_listen_diagnostics_contracts"
    "runtime_command_service_contracts"
    "editor_tool_executor_contracts"
    "tool_loader_contracts"
    "tool_manifest_contracts"
    "plugin_action_router_contracts"
    "plugin_entrypoint_contracts"
    "plugin_reload_coordinator_contracts"
    "plugin_instance_freshness_contracts"
    "plugin_runtime_reload_executor_contracts"
    "plugin_runtime_state_contracts"
    "server_runtime_settings_projection_service_contracts"
    "external_host_removal_audit"
    "system_help_contracts"
    "json_rpc_request_service_contracts"
    "system_project_executor_contracts"
    "system_scene_executor_contracts"
    "client_install_detection_service_contracts"
    "client_detector_registry_contracts"
    "config_tab_action_service_contracts"
    "client_config_presenter_contracts"
    "config_tab_rendering_contracts"
    "home_tab_localization_contracts"
    "server_tab_model_projection_contracts"
    "mcp_debug_buffer_contracts"
    "tool_presentation_service_contracts"
    "tools_api_service_contracts"
    "tool_rpc_router_contracts"
    "dock_model_service_contracts"
    "tools_tab_rendering_contracts"
)

$TimingRecords = New-Object System.Collections.Generic.List[object]
$OverallStopwatch = [System.Diagnostics.Stopwatch]::StartNew()

try {
    $TimingRecords.Add((Invoke-CommandOrThrow -Description "Build plugin Roslyn library" -Command {
        Invoke-DotnetBuildWithDiagnostics -Description "Build plugin Roslyn library" -ProjectPath ".\addons\godot_dotnet_mcp\dotnet_bridge\DotnetBridge.csproj" -Configuration Release
    }))

    $TimingRecords.Add((Invoke-CommandOrThrow -Description "Build harness runner" -Command {
        Invoke-DotnetBuildWithDiagnostics -Description "Build harness runner" -ProjectPath ".\tests\godot_plugin_harness\GodotPluginHarness.csproj" -Configuration Release
    }))

    $TimingRecords.Add((Invoke-CommandOrThrow -Description "Build fixture Godot C# project" -Command {
        Invoke-DotnetBuildWithDiagnostics -Description "Build fixture Godot C# project" -ProjectPath ".\tests\godot_plugin_harness_fixture\GodotDotnetMcpPluginHarness.csproj" -Configuration Release
    }))

    $manifestResult = Invoke-Harness -Description "List harness cases" -ExtraArgs @("--list-cases")
    $TimingRecords.Add((New-TimingRecord -Name "List harness cases" -Duration $manifestResult.Duration))
    $discoveredCases = @()
    if ($manifestResult.Json -ne $null -and $manifestResult.Json.PSObject.Properties.Name -contains "discovered") {
        $discoveredCases = @($manifestResult.Json.discovered | ForEach-Object { [string]$_.name })
    }

    foreach ($caseName in $RequiredCases) {
        if ($discoveredCases -notcontains $caseName) {
            throw "Required harness case was not discovered: $caseName"
        }
    }

    foreach ($caseName in $RequiredCases) {
        $env:GODOT_PLUGIN_HARNESS_ONLY_CASE = $caseName
        $caseResult = Invoke-Harness -Description "Run harness case: $caseName" -ExtraArgs @()
        $TimingRecords.Add((New-TimingRecord -Name "Run harness case: $caseName" -Duration $caseResult.Duration))
    }

    Remove-Item Env:\GODOT_PLUGIN_HARNESS_ONLY_CASE -ErrorAction SilentlyContinue

    $TimingRecords.Add((Invoke-CommandOrThrow -Description "Validate refactor guardrails" -Command {
        .\scripts\validate_refactor_guardrails.ps1
    }))

    Write-Host "Plugin harness verification completed successfully."
}
finally {
    Remove-Item Env:\GODOT_PLUGIN_HARNESS_ONLY_CASE -ErrorAction SilentlyContinue
    Invoke-HarnessProcessCleanup

    $cleanupPaths = @(
        ".\tests\godot_plugin_harness\bin",
        ".\tests\godot_plugin_harness\obj",
        ".\tests\godot_plugin_harness\.godot",
        ".\tests\godot_plugin_harness_fixture\.godot",
        ".\addons\godot_dotnet_mcp\dotnet_bridge\bin",
        ".\addons\godot_dotnet_mcp\dotnet_bridge\obj",
        ".\.tmp\godot_plugin_harness",
        ".\dist",
        ".\release_dist"
    )

    foreach ($path in $cleanupPaths) {
        Remove-IfExists -Path (Join-Path $repoRoot $path)
    }

    $OverallStopwatch.Stop()
    Write-HarnessTimingSummary -Timings $TimingRecords.ToArray() -TotalDuration $OverallStopwatch.Elapsed
}

