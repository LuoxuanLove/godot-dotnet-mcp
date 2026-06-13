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
        [TimeSpan]$Duration,
        [object[]]$CaseTimings = @()
    )

    return [pscustomobject]@{
        Name = $Name
        Duration = $Duration
        CaseTimings = @($CaseTimings)
    }
}

function Format-CaseList {
    param(
        [string[]]$Cases
    )

    return ($Cases -join ",")
}

function Assert-ManifestValue {
    param(
        [object]$Case,
        [string]$FieldName,
        [string[]]$AllowedValues
    )

    if (-not ($Case.PSObject.Properties.Name -contains $FieldName)) {
        throw "Contract case manifest entry '$($Case.name)' is missing required field: $FieldName"
    }

    $value = [string]$Case.$FieldName
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw "Contract case manifest entry '$($Case.name)' has an empty required field: $FieldName"
    }

    if ($AllowedValues.Count -gt 0 -and $AllowedValues -notcontains $value) {
        throw "Contract case manifest entry '$($Case.name)' has invalid $FieldName '$value'. Allowed values: $($AllowedValues -join ', ')"
    }
}

function Get-ContractCaseManifest {
    param([string]$ManifestPath)

    if (-not (Test-Path -LiteralPath $ManifestPath)) {
        throw "Contract case manifest was not found: $ManifestPath"
    }

    $manifest = Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($manifest -isnot [array]) {
        $manifest = @($manifest)
    }
    if ($manifest.Count -eq 0) {
        throw "Contract case manifest must contain at least one case."
    }

    $names = New-Object System.Collections.Generic.HashSet[string]
    foreach ($case in $manifest) {
        Assert-ManifestValue -Case $case -FieldName "name" -AllowedValues @()
        Assert-ManifestValue -Case $case -FieldName "layer" -AllowedValues @()
        Assert-ManifestValue -Case $case -FieldName "domain" -AllowedValues @()
        Assert-ManifestValue -Case $case -FieldName "behavior" -AllowedValues @("current", "migration", "deprecation", "removal_guard")
        Assert-ManifestValue -Case $case -FieldName "mcp_version" -AllowedValues @("2025-11-25", "2025-06-18", "legacy")
        Assert-ManifestValue -Case $case -FieldName "conformance" -AllowedValues @("required", "compat", "optional")
        Assert-ManifestValue -Case $case -FieldName "speed" -AllowedValues @("fast", "headless", "editor", "release")
        Assert-ManifestValue -Case $case -FieldName "isolation" -AllowedValues @("pure", "user_fs", "stage_root", "editor")
        Assert-ManifestValue -Case $case -FieldName "v2_0_disposition" -AllowedValues @("keep", "rewrite", "delete", "expires")

        $isLegacyOrRemoval = $case.behavior -in @("deprecation", "removal_guard") -or $case.v2_0_disposition -in @("delete", "expires")
        if ($isLegacyOrRemoval -and [string]$case.conformance -ne "compat") {
            throw "Contract case manifest entry '$($case.name)' covers legacy/removal behavior and must use conformance='compat'."
        }
        if (-not $isLegacyOrRemoval -and [string]$case.mcp_version -eq "legacy") {
            throw "Contract case manifest entry '$($case.name)' targets current behavior and must not use mcp_version='legacy'."
        }

        if (-not $names.Add([string]$case.name)) {
            throw "Contract case manifest contains duplicate case name: $($case.name)"
        }
    }

    return $manifest
}

# Historical runnable contract cases that predate the v2.0 manifest gate. New
# runnable contract cases must be added to scripts\contract_case_manifest.json.
$LegacyUnmanifestedContractCases = @(
    "client_config_file_detector_contracts|res://tests/client_config_file_detector_contract_test.gd",
    "client_config_file_transaction_contracts|res://tests/client_config_file_transaction_contract_test.gd",
    "client_config_inspection_service_contracts|res://tests/client_config_inspection_service_contract_test.gd",
    "client_config_launcher_adapter_contracts|res://tests/client_config_launcher_adapter_contract_test.gd",
    "client_config_serializer_contracts|res://tests/client_config_serializer_contract_test.gd",
    "client_executable_detector_contracts|res://tests/client_executable_detector_contract_test.gd",
    "client_install_config_entry_inspector_contracts|res://tests/client_install_config_entry_inspector_contract_test.gd",
    "client_install_path_resolver_contracts|res://tests/client_install_path_resolver_contract_test.gd",
    "client_install_runtime_inspector_contracts|res://tests/client_install_runtime_inspector_contract_test.gd",
    "debug_tool_executor_contracts|res://tests/debug_tool_executor_contract_test.gd",
    "editor_lifecycle_action_service_contracts|res://tests/editor_lifecycle_action_service_contract_test.gd",
    "editor_lifecycle_endpoint_contracts|res://tests/editor_lifecycle_endpoint_contract_test.gd",
    "editor_lifecycle_state_builder_contracts|res://tests/editor_lifecycle_state_builder_contract_test.gd",
    "filesystem_tool_executor_contracts|res://tests/filesystem_tool_executor_contract_test.gd",
    "gdscript_lsp_diagnostics_service_contracts|res://tests/gdscript_lsp_diagnostics_service_contract_test.gd",
    "geometry_tool_executor_contracts|res://tests/geometry_tool_executor_contract_test.gd",
    "group_tool_executor_contracts|res://tests/group_tool_executor_contract_test.gd",
    "http_request_router_contracts|res://tests/http_request_router_contract_test.gd",
    "http_response_service_contracts|res://tests/http_response_service_contract_test.gd",
    "http_server_contracts|res://tests/http_server_contract_test.gd",
    "json_rpc_router_contracts|res://tests/json_rpc_router_contract_test.gd",
    "lighting_tool_executor_contracts|res://tests/lighting_tool_executor_contract_test.gd",
    "lsp_client_contracts|res://tests/lsp_client_contract_test.gd",
    "lsp_service_access_contracts|res://tests/lsp_service_access_contract_test.gd",
    "material_tool_executor_contracts|res://tests/material_tool_executor_contract_test.gd",
    "mcp_dock_settings_tab_contracts|res://tests/mcp_dock_settings_tab_contract_test.gd",
    "mcp_maintenance_contracts|res://tests/mcp_maintenance_contract_test.gd",
    "navigation_tool_executor_contracts|res://tests/navigation_tool_executor_contract_test.gd",
    "node_tool_executor_contracts|res://tests/node_tool_executor_contract_test.gd",
    "particle_tool_executor_contracts|res://tests/particle_tool_executor_contract_test.gd",
    "physics_tool_executor_contracts|res://tests/physics_tool_executor_contract_test.gd",
    "plugin_dock_coordinator_contracts|res://tests/plugin_dock_coordinator_contract_test.gd",
    "plugin_runtime_coordinator_contracts|res://tests/plugin_runtime_coordinator_contract_test.gd",
    "plugin_self_diagnostic_store_contracts|res://tests/plugin_self_diagnostic_store_contract_test.gd",
    "project_tool_executor_contracts|res://tests/project_tool_executor_contract_test.gd",
    "resource_tool_executor_contracts|res://tests/resource_tool_executor_contract_test.gd",
    "runtime_bridge_invalid_action_fallback|res://tests/runtime_bridge_contract_test.gd",
    "runtime_control_contracts|res://tests/runtime_control_contract_test.gd",
    "runtime_control_reply_resolver_contracts|res://tests/runtime_control_reply_resolver_contract_test.gd",
    "runtime_control_request_coordinator_contracts|res://tests/runtime_control_request_coordinator_contract_test.gd",
    "runtime_fallback_store_contracts|res://tests/runtime_fallback_store_contract_test.gd",
    "runtime_reply_service_contracts|res://tests/runtime_reply_service_contract_test.gd",
    "scene_tool_executor_contracts|res://tests/scene_tool_executor_contract_test.gd",
    "script_edit_service_contracts|res://tests/script_edit_service_contract_test.gd",
    "script_tool_executor_contracts|res://tests/script_tool_executor_contract_test.gd",
    "server_runtime_lsp_diagnostics_snapshot_service_contracts|res://tests/server_runtime_lsp_diagnostics_snapshot_service_contract_test.gd",
    "settings_tab_model_projection_contracts|res://tests/settings_tab_model_projection_contract_test.gd",
    "settings_tab_rendering_contracts|res://tests/settings_tab_rendering_contract_test.gd",
    "shader_tool_executor_contracts|res://tests/shader_tool_executor_contract_test.gd",
    "stdio_tool_activity_contracts|res://tests/stdio_tool_activity_contract_test.gd",
    "system_editor_control_contracts|res://tests/system_editor_control_contract_test.gd",
    "system_index_impl_contracts|res://tests/system_index_impl_contract_test.gd",
    "system_script_executor_contracts|res://tests/system_script_executor_contract_test.gd",
    "system_settings_dialog_contracts|res://tests/system_settings_dialog_contract_test.gd",
    "tool_activity_registry_contracts|res://tests/tool_activity_registry_contract_test.gd",
    "tool_lsp_diagnostics_adapter_contracts|res://tests/tool_lsp_diagnostics_adapter_contract_test.gd",
    "user_tool_maintenance_service_contracts|res://tests/user_tool_maintenance_service_contract_test.gd",
    "user_tool_watch_service_contracts|res://tests/user_tool_watch_service_contract_test.gd"
)

function Assert-DiscoveredCasesAreManifested {
    param(
        [object[]]$Discovered,
        [string[]]$ManifestCaseNames,
        [string[]]$LegacyAllowlist = @()
    )

    $manifestLookup = New-Object System.Collections.Generic.HashSet[string]
    foreach ($caseName in $ManifestCaseNames) {
        [void]$manifestLookup.Add([string]$caseName)
    }
    $legacyLookup = New-Object System.Collections.Generic.HashSet[string]
    foreach ($legacyCase in $LegacyAllowlist) {
        [void]$legacyLookup.Add([string]$legacyCase)
    }

    $missing = New-Object System.Collections.Generic.List[string]
    foreach ($case in $Discovered) {
        $name = [string]$case.name
        if ([string]::IsNullOrWhiteSpace($name)) {
            continue
        }

        if ($manifestLookup.Contains($name)) {
            continue
        }

        $status = ""
        if ($case.PSObject.Properties.Name -contains "status") {
            $status = [string]$case.status
        }
        if ($status -eq "headless_incompatible" -or $status -eq "load_error" -or $status -eq "missing_run_case") {
            continue
        }

        $path = ""
        if ($case.PSObject.Properties.Name -contains "path") {
            $path = [string]$case.path
        }
        $caseKey = "{0}|{1}" -f $name, $path
        if ($legacyLookup.Contains($caseKey)) {
            continue
        }

        if ([string]::IsNullOrWhiteSpace($path)) {
            $missing.Add($name)
        }
        else {
            $missing.Add("$name ($path)")
        }
    }

    if ($missing.Count -gt 0) {
        $joined = [string]::Join(", ", [string[]]$missing.ToArray())
        throw "Discovered runnable contract case(s) missing from scripts\contract_case_manifest.json or the legacy allowlist: $joined"
    }
}

function Get-SuiteResults {
    param(
        [object]$HarnessJson
    )

    if ($HarnessJson -eq $null -or -not ($HarnessJson.PSObject.Properties.Name -contains "suite")) {
        return @()
    }

    $suite = $HarnessJson.suite
    if ($suite -eq $null) {
        return @()
    }

    if ($suite.PSObject.Properties.Name -contains "results") {
        return @($suite.results)
    }

    if ($suite.PSObject.Properties.Name -contains "name") {
        return @($suite)
    }

    return @()
}

function Get-CaseTimingRecords {
    param(
        [object]$HarnessJson
    )

    $records = New-Object System.Collections.Generic.List[object]
    foreach ($result in (Get-SuiteResults -HarnessJson $HarnessJson)) {
        $caseName = [string]$result.name
        if ([string]::IsNullOrWhiteSpace($caseName)) {
            continue
        }

        $durationMs = 0
        if ($result.PSObject.Properties.Name -contains "duration_ms") {
            $durationMs = [int64]$result.duration_ms
        }

        $records.Add([pscustomobject]@{
            Name = $caseName
            Duration = [TimeSpan]::FromMilliseconds($durationMs)
            Success = [bool]$result.success
        })
    }

    return $records.ToArray()
}

function Assert-HarnessResults {
    param(
        [object]$HarnessJson,
        [string[]]$ExpectedCases,
        [string]$Description
    )

    $results = Get-SuiteResults -HarnessJson $HarnessJson
    $resultNames = @($results | ForEach-Object { [string]$_.name })

    foreach ($caseName in $ExpectedCases) {
        if ($resultNames -notcontains $caseName) {
            throw "$Description did not report required harness case: $caseName"
        }
    }

    foreach ($resultName in $resultNames) {
        if ($ExpectedCases -notcontains $resultName) {
            throw "$Description reported unexpected harness case: $resultName"
        }
    }

    foreach ($result in $results) {
        if (-not [bool]$result.success) {
            throw "$Description reported failed harness case: $($result.name). $($result.error)"
        }
    }
}

function Assert-CleanAssetLibraryInstallBuild {
    param(
        [object]$HarnessJson
    )

    if ($HarnessJson -eq $null) {
        throw "Clean Asset Library install build did not report JSON output."
    }

    if (-not ($HarnessJson.PSObject.Properties.Name -contains "exportedWithGitArchive") -or -not [bool]$HarnessJson.exportedWithGitArchive) {
        throw "Clean Asset Library install build did not report exportedWithGitArchive=true."
    }

    $requiredFalseProperties = @(
        "fixtureHasRoslynPackageReference",
        "exportedRoslynRuntimeSources",
        "exportedDotnetBridgeSources"
    )

    foreach ($propertyName in $requiredFalseProperties) {
        if (-not ($HarnessJson.PSObject.Properties.Name -contains $propertyName)) {
            throw "Clean Asset Library install build did not report required property: $propertyName"
        }

        if ([bool]$HarnessJson.$propertyName) {
            throw "Clean Asset Library install build reported $propertyName=true."
        }
    }

    if (-not ($HarnessJson.PSObject.Properties.Name -contains "exportedRoslynRuntimeManifest")) {
        throw "Clean Asset Library install build did not report required property: exportedRoslynRuntimeManifest"
    }

    if (-not [bool]$HarnessJson.exportedRoslynRuntimeManifest) {
        throw "Clean Asset Library install build did not include the isolated Roslyn runtime manifest."
    }

    if (-not ($HarnessJson.PSObject.Properties.Name -contains "exportedRoslynRuntimeExecutable")) {
        throw "Clean Asset Library install build did not report required property: exportedRoslynRuntimeExecutable"
    }

    if (-not [bool]$HarnessJson.exportedRoslynRuntimeExecutable) {
        throw "Clean Asset Library install build did not include the isolated Roslyn runtime executable."
    }

    if (-not ($HarnessJson.PSObject.Properties.Name -contains "exportedRoslynRuntimeProbeSucceeded")) {
        throw "Clean Asset Library install build did not report required property: exportedRoslynRuntimeProbeSucceeded"
    }

    if (-not [bool]$HarnessJson.exportedRoslynRuntimeProbeSucceeded) {
        throw "Clean Asset Library install build could not execute the isolated Roslyn runtime probe."
    }

    if (-not ($HarnessJson.PSObject.Properties.Name -contains "exportedPluginRoslynServiceProbeSucceeded")) {
        throw "Clean Asset Library install build did not report required property: exportedPluginRoslynServiceProbeSucceeded"
    }

    if (-not [bool]$HarnessJson.exportedPluginRoslynServiceProbeSucceeded) {
        throw "Clean Asset Library install build could not execute PluginRoslynService through the exported isolated runtime process."
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
        foreach ($caseTiming in @($timing.CaseTimings)) {
            Write-Host "    - $($caseTiming.Name): $(Format-Duration -Duration $caseTiming.Duration)"
        }
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

        $caseTimingRows = @($Timings | ForEach-Object { $_.CaseTimings } | Where-Object { $_ -ne $null })
        if ($caseTimingRows.Count -gt 0) {
            $summaryLines += ""
            $summaryLines += "| Case | Duration | Result |"
            $summaryLines += "| --- | ---: | --- |"
            foreach ($caseTiming in ($caseTimingRows | Sort-Object Duration -Descending)) {
                $result = if ($caseTiming.Success) { "passed" } else { "failed" }
                $summaryLines += "| $($caseTiming.Name) | $(Format-Duration -Duration $caseTiming.Duration) | $result |"
            }
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

function Format-HarnessJsonValue {
    param(
        [object]$Value
    )

    if ($Value -eq $null) {
        return "<none>"
    }

    if ($Value -is [array]) {
        $items = @($Value | ForEach-Object { [string]$_ }) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        if ($items.Count -eq 0) {
            return "<none>"
        }

        return ($items -join ",")
    }

    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) {
        return "<none>"
    }

    return $text
}

function Format-HarnessFailureSummary {
    param(
        [object]$HarnessJson
    )

    if ($HarnessJson -eq $null) {
        return "Harness failure summary: json=<none>"
    }

    $propertyNames = @($HarnessJson.PSObject.Properties.Name)
    $failureClasses = if ($propertyNames -contains "failureClasses") {
        Format-HarnessJsonValue -Value @($HarnessJson.failureClasses)
    } elseif ($propertyNames -contains "failureClass") {
        Format-HarnessJsonValue -Value $HarnessJson.failureClass
    } else {
        "<none>"
    }
    $primaryFailureClass = if ($propertyNames -contains "primaryFailureClass") { Format-HarnessJsonValue -Value $HarnessJson.primaryFailureClass } else { Format-HarnessJsonValue -Value $HarnessJson.failureClass }
    $exitCleanupPolicy = if ($propertyNames -contains "exitCleanupWarningPolicy") { Format-HarnessJsonValue -Value $HarnessJson.exitCleanupWarningPolicy } else { "<unknown>" }
    $exitCleanupWarnings = if ($propertyNames -contains "exitCleanupWarningsDetected") { [string][bool]$HarnessJson.exitCleanupWarningsDetected } else { "unknown" }
    $runtimeMarkers = if ($propertyNames -contains "runtimeErrorMarkersDetected") { [string][bool]$HarnessJson.runtimeErrorMarkersDetected } else { "unknown" }
    $suiteSuccess = if ($propertyNames -contains "suiteSuccess") { Format-HarnessJsonValue -Value $HarnessJson.suiteSuccess } else { "<unknown>" }
    $exitCode = if ($propertyNames -contains "exitCode") { Format-HarnessJsonValue -Value $HarnessJson.exitCode } else { "<unknown>" }
    $reason = if ($propertyNames -contains "reason") { Format-HarnessJsonValue -Value $HarnessJson.reason } else { "<none>" }

    return "Harness failure summary: failureClasses=$failureClasses; primaryFailureClass=$primaryFailureClass; reason=$reason; exitCode=$exitCode; suiteSuccess=$suiteSuccess; runtimeErrorMarkersDetected=$runtimeMarkers; exitCleanupWarningsDetected=$exitCleanupWarnings; exitCleanupWarningPolicy=$exitCleanupPolicy"
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
            $summary = Format-HarnessFailureSummary -HarnessJson $json
            throw "$Description failed with exit code $exitCode.`n$summary`n$details"
        }

        if ($json -ne $null -and ($json.PSObject.Properties.Name -contains "success") -and -not [bool]$json.success) {
            $summary = Format-HarnessFailureSummary -HarnessJson $json
            throw "$Description reported success=false.`n$summary`n$($outputText)"
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
$ContractCaseManifest = Get-ContractCaseManifest -ManifestPath (Join-Path $repoRoot "scripts\contract_case_manifest.json")
$ManifestCaseNames = @($ContractCaseManifest | ForEach-Object { [string]$_.name })
$RequiredCases = @($ContractCaseManifest | Where-Object { [string]$_.v2_0_disposition -ne "expires" } | ForEach-Object { [string]$_.name })
$IsolatedHeadlessCases = @($ContractCaseManifest | Where-Object { [string]$_.name -eq "tools_tab_rendering_contracts" } | ForEach-Object { [string]$_.name })
$EditorProbeCases = @($ContractCaseManifest | Where-Object { [string]$_.speed -eq "editor" -or [string]$_.isolation -eq "editor" } | ForEach-Object { [string]$_.name })

$TimingRecords = New-Object System.Collections.Generic.List[object]
$OverallStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$HarnessSucceeded = $false

try {
    $TimingRecords.Add((Invoke-CommandOrThrow -Description "Build plugin Roslyn library" -Command {
        Invoke-DotnetBuildWithDiagnostics -Description "Build plugin Roslyn library" -ProjectPath ".\addons\godot_dotnet_mcp\dotnet_bridge\DotnetBridge.csproj" -Configuration Release
    }))

    $TimingRecords.Add((Invoke-CommandOrThrow -Description "Validate isolated Roslyn runtime bundle" -Command {
        & .\scripts\validate_roslyn_runtime_bundle.ps1 -Configuration Release
        if ($LASTEXITCODE -ne 0) {
            throw "Validate isolated Roslyn runtime bundle failed with exit code $LASTEXITCODE."
        }
    }))

    $TimingRecords.Add((Invoke-CommandOrThrow -Description "Build harness runner" -Command {
        Invoke-DotnetBuildWithDiagnostics -Description "Build harness runner" -ProjectPath ".\tests\godot_plugin_harness\GodotPluginHarness.csproj" -Configuration Release
    }))

    $TimingRecords.Add((Invoke-CommandOrThrow -Description "Build fixture Godot C# project" -Command {
        Invoke-DotnetBuildWithDiagnostics -Description "Build fixture Godot C# project" -ProjectPath ".\tests\godot_plugin_harness_fixture\GodotDotnetMcpPluginHarness.csproj" -Configuration Release
    }))

    $cleanInstallResult = Invoke-Harness -Description "Build clean Asset Library install fixture" -ExtraArgs @("--clean-asset-library-install-build", "--keep-stage-root")
    Assert-CleanAssetLibraryInstallBuild -HarnessJson $cleanInstallResult.Json
    $TimingRecords.Add((New-TimingRecord -Name "Build clean Asset Library install fixture" -Duration $cleanInstallResult.Duration))

    $manifestResult = Invoke-Harness -Description "List harness cases" -ExtraArgs @("--list-cases", "--keep-stage-root")
    $TimingRecords.Add((New-TimingRecord -Name "List harness cases" -Duration $manifestResult.Duration))
    $discoveredManifestEntries = @()
    $discoveredCases = @()
    if ($manifestResult.Json -ne $null -and $manifestResult.Json.PSObject.Properties.Name -contains "discovered") {
        $discoveredManifestEntries = @($manifestResult.Json.discovered)
        $discoveredCases = @($discoveredManifestEntries | ForEach-Object { [string]$_.name })
    }

    Assert-DiscoveredCasesAreManifested -Discovered $discoveredManifestEntries -ManifestCaseNames $ManifestCaseNames -LegacyAllowlist $LegacyUnmanifestedContractCases

    $requiredDiscoverableCases = @($RequiredCases | Where-Object { $EditorProbeCases -notcontains $_ })
    foreach ($caseName in $requiredDiscoverableCases) {
        if ($discoveredCases -notcontains $caseName) {
            throw "Required harness case was not discovered: $caseName"
        }
    }

    $requiredHeadlessCases = @($RequiredCases | Where-Object { $EditorProbeCases -notcontains $_ -and $IsolatedHeadlessCases -notcontains $_ })
    if ($requiredHeadlessCases.Count -gt 0) {
        Remove-Item Env:\GODOT_PLUGIN_HARNESS_ONLY_CASE -ErrorAction SilentlyContinue
        $headlessResult = Invoke-Harness -Description "Run required headless harness cases" -ExtraArgs @("--keep-stage-root", "--cases", (Format-CaseList -Cases $requiredHeadlessCases))
        Assert-HarnessResults -HarnessJson $headlessResult.Json -ExpectedCases $requiredHeadlessCases -Description "Required headless harness batch"
        $TimingRecords.Add((New-TimingRecord -Name "Run required headless harness cases" -Duration $headlessResult.Duration -CaseTimings (Get-CaseTimingRecords -HarnessJson $headlessResult.Json)))
    }

    foreach ($caseName in $IsolatedHeadlessCases) {
        Remove-Item Env:\GODOT_PLUGIN_HARNESS_ONLY_CASE -ErrorAction SilentlyContinue
        $caseResult = Invoke-Harness -Description "Run isolated headless harness case: $caseName" -ExtraArgs @("--keep-stage-root", "--cases", $caseName)
        Assert-HarnessResults -HarnessJson $caseResult.Json -ExpectedCases @($caseName) -Description "Isolated headless harness case"
        $TimingRecords.Add((New-TimingRecord -Name "Run isolated headless harness case: $caseName" -Duration $caseResult.Duration -CaseTimings (Get-CaseTimingRecords -HarnessJson $caseResult.Json)))
    }

    foreach ($caseName in $EditorProbeCases) {
        $env:GODOT_PLUGIN_HARNESS_ONLY_CASE = $caseName
        $caseResult = Invoke-Harness -Description "Run harness case: $caseName" -ExtraArgs @("--keep-stage-root")
        Assert-HarnessResults -HarnessJson $caseResult.Json -ExpectedCases @($caseName) -Description "Isolated editor probe harness case"
        $TimingRecords.Add((New-TimingRecord -Name "Run harness case: $caseName" -Duration $caseResult.Duration -CaseTimings (Get-CaseTimingRecords -HarnessJson $caseResult.Json)))
    }

    Remove-Item Env:\GODOT_PLUGIN_HARNESS_ONLY_CASE -ErrorAction SilentlyContinue

    $TimingRecords.Add((Invoke-CommandOrThrow -Description "Validate refactor guardrails" -Command {
        .\scripts\validate_refactor_guardrails.ps1
    }))

    $HarnessSucceeded = $true
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
        ".\dist",
        ".\release_dist"
    )

    if ($HarnessSucceeded) {
        $cleanupPaths += ".\.tmp\godot_plugin_harness"
    }

    foreach ($path in $cleanupPaths) {
        Remove-IfExists -Path (Join-Path $repoRoot $path)
    }

    $OverallStopwatch.Stop()
    Write-HarnessTimingSummary -Timings $TimingRecords.ToArray() -TotalDuration $OverallStopwatch.Elapsed
}
