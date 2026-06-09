param(
    [string]$RepositoryRoot = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    $RepositoryRoot = Split-Path -Parent $PSScriptRoot
}

function Read-Workflow {
    param([Parameter(Mandatory = $true)][string]$RelativePath)

    $path = Join-Path $RepositoryRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Required workflow is missing: $RelativePath"
    }

    return Get-Content -LiteralPath $path -Encoding UTF8 -Raw
}

function Assert-Contains {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Content,
        [Parameter(Mandatory = $true)][string]$Expected
    )

    if (-not $Content.Contains($Expected)) {
        throw "$Name must contain: $Expected"
    }
}

$publishPlugin = Read-Workflow ".github/workflows/publish-plugin.yml"
$publishRelease = Read-Workflow ".github/workflows/publish-release.yml"
$dotnetBuild = Read-Workflow ".github/workflows/dotnet-build.yml"
$v2Bridge = Read-Workflow ".github/workflows/v2-bridge-contract.yml"
$v2Broker = Read-Workflow ".github/workflows/v2-broker-manifest.yml"

$companionChecks = @(
    "addons\godot_dotnet_mcp\companion\GodotDotnetMcp.Companion\GodotDotnetMcp.Companion.csproj",
    "tests\companion_contracts\GodotDotnetMcp.Companion.Contracts.csproj",
    "addons\godot_dotnet_mcp\companion\GodotDotnetMcp.Companion.StaticAnalysis\GodotDotnetMcp.Companion.StaticAnalysis.csproj",
    "tests\static_project_analyzer\GodotDotnetMcp.Companion.StaticAnalysis.Tests.csproj"
)

foreach ($check in $companionChecks) {
    Assert-Contains "publish-plugin" $publishPlugin $check
    Assert-Contains "publish-release" $publishRelease $check
    Assert-Contains "dotnet-build" $dotnetBuild $check
}

foreach ($field in @("companion_contract_checked", "companion_static_analyzer_checked")) {
    Assert-Contains "publish-release dry-run validation" $publishRelease "`$record.$field -eq `$true"
    Assert-Contains "publish-release dry-run record" $publishRelease "$field = `$true"
}

$v2PolicyChecks = @(
    ".\scripts\validate_v2_bridge_contract.ps1",
    ".\scripts\test_v2_bridge_contract.ps1",
    ".\scripts\validate_v2_broker_manifest.ps1",
    ".\scripts\test_v2_broker_manifest.ps1"
)

foreach ($check in $v2PolicyChecks) {
    Assert-Contains "publish-plugin" $publishPlugin $check
    Assert-Contains "publish-release" $publishRelease $check
}

foreach ($field in @(
    "v2_bridge_contract_checked",
    "v2_bridge_contract_tests_checked",
    "v2_broker_manifest_checked",
    "v2_broker_manifest_tests_checked"
)) {
    Assert-Contains "publish-release dry-run validation" $publishRelease "`$record.$field -eq `$true"
    Assert-Contains "publish-release dry-run record" $publishRelease "$field = `$true"
}

foreach ($workflow in @(
    @{ Name = "dotnet-build"; Content = $dotnetBuild },
    @{ Name = "v2-bridge-contract"; Content = $v2Bridge },
    @{ Name = "v2-broker-manifest"; Content = $v2Broker }
)) {
    Assert-Contains $workflow.Name $workflow.Content "release/v2.0.0-baseline"
}

Write-Host "v2 release workflow validation passed."
