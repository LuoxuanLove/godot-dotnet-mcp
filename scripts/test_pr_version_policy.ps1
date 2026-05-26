$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $PSScriptRoot
$validatorPath = Join-Path $scriptRoot "scripts\validate_pr_version_policy.ps1"
$metadataFiles = @(
    "addons/godot_dotnet_mcp/plugin.cfg",
    "addons/godot_dotnet_mcp/plugin/runtime/mcp_protocol_facts.json",
    "addons/godot_dotnet_mcp/plugin/runtime/mcp_protocol_facts.gd",
    "addons/godot_dotnet_mcp/dotnet_bridge/DotnetBridge.csproj"
)

function Convert-ToAssemblyVersion {
    param([string]$Version)
    return "$Version.0"
}

function Write-MetadataFixture {
    param(
        [string]$RepositoryRoot,
        [string]$Version,
        [string]$PluginDescription = "Policy fixture"
    )

    $pluginDir = Join-Path $RepositoryRoot "addons\godot_dotnet_mcp"
    $factsDir = Join-Path $pluginDir "plugin\runtime"
    $bridgeDir = Join-Path $pluginDir "dotnet_bridge"
    New-Item -ItemType Directory -Path $pluginDir, $factsDir, $bridgeDir -Force | Out-Null

    @"
[plugin]
name="Godot .NET MCP"
description="$PluginDescription"
version="$Version"
script="plugin.gd"
"@ | Set-Content -LiteralPath (Join-Path $RepositoryRoot $metadataFiles[0]) -Encoding UTF8

    @"
{
  "protocol_version": "2025-06-18",
  "tool_schema_version": "2026-05-03.10",
  "server_name": "godot-dotnet-mcp",
  "server_version": "$Version"
}
"@ | Set-Content -LiteralPath (Join-Path $RepositoryRoot $metadataFiles[1]) -Encoding UTF8

    @"
static func _default_facts() -> Dictionary:
`treturn {
`t`t"protocol_version": "2025-06-18",
`t`t"tool_schema_version": "2026-05-03.10",
`t`t"server_name": "godot-dotnet-mcp",
`t`t"server_version": "$Version"
`t}
"@ | Set-Content -LiteralPath (Join-Path $RepositoryRoot $metadataFiles[2]) -Encoding UTF8

    $assemblyVersion = Convert-ToAssemblyVersion -Version $Version
    @"
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <Version>$Version</Version>
    <VersionPrefix>$Version</VersionPrefix>
    <AssemblyVersion>$assemblyVersion</AssemblyVersion>
    <FileVersion>$assemblyVersion</FileVersion>
    <InformationalVersion>$Version</InformationalVersion>
  </PropertyGroup>
</Project>
"@ | Set-Content -LiteralPath (Join-Path $RepositoryRoot $metadataFiles[3]) -Encoding UTF8
}

function New-PolicyFixture {
    param(
        [string]$BaseVersion = "1.0.0",
        [string]$HeadVersion = "1.0.0",
        [string]$HeadBranch = "feature/tooling",
        [scriptblock]$MutateHead = $null
    )

    $repo = Join-Path ([System.IO.Path]::GetTempPath()) ("godot-dotnet-mcp-version-policy-" + [System.Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $repo | Out-Null
    Write-MetadataFixture -RepositoryRoot $repo -Version $BaseVersion -PluginDescription "Base fixture"

    git -C $repo init -q
    git -C $repo config user.email "ci@example.invalid"
    git -C $repo config user.name "CI"
    git -C $repo add addons
    git -C $repo commit -m "base" -q
    git -C $repo branch -M dev

    git -C $repo switch -c $HeadBranch -q
    Write-MetadataFixture -RepositoryRoot $repo -Version $HeadVersion
    if ($null -ne $MutateHead) {
        & $MutateHead $repo
    }
    git -C $repo add addons
    git -C $repo commit -m "head" -q

    return $repo
}

function Invoke-PolicyScenario {
    param(
        [string]$Name,
        [string]$HeadBranch,
        [string]$BaseVersion = "1.0.0",
        [string]$HeadVersion = "1.0.0",
        [scriptblock]$MutateHead = $null,
        [bool]$ShouldPass,
        [string]$RepositoryOwner = "LuoxuanLove",
        [string]$HeadRepositoryOwner = "LuoxuanLove",
        [string]$ExpectedErrorContains = "",
        [switch]$RequireTrustedReleaseBranch
    )

    $repo = New-PolicyFixture -BaseVersion $BaseVersion -HeadVersion $HeadVersion -HeadBranch $HeadBranch -MutateHead $MutateHead
    try {
        $headCommit = (git -C $repo rev-parse HEAD).Trim()
        $passed = $true
        $failureMessage = ""
        try {
            & $validatorPath -RepositoryRoot $repo -BaseBranch "dev" -HeadBranch $HeadBranch -BaseRef "dev" -HeadRef $headCommit -RepositoryOwner $RepositoryOwner -HeadRepositoryOwner $HeadRepositoryOwner -RequireTrustedReleaseBranch:$RequireTrustedReleaseBranch -SkipFetch | Out-Host
        } catch {
            $passed = $false
            $failureMessage = $_.Exception.Message
            Write-Host "Scenario '$Name' failed as expected candidate: $failureMessage"
        }

        if ($passed -ne $ShouldPass) {
            throw "Scenario '$Name' expected pass=$ShouldPass but got pass=$passed."
        }

        if (-not $ShouldPass) {
            if ([string]::IsNullOrWhiteSpace($ExpectedErrorContains)) {
                throw "Scenario '$Name' must declare an expected failure message."
            }

            if ($failureMessage -notlike "*$ExpectedErrorContains*") {
                throw "Scenario '$Name' failed with unexpected message: $failureMessage"
            }
        }

        Write-Host "Scenario '$Name' passed."
    } finally {
        Remove-Item -LiteralPath $repo -Recurse -Force
    }
}

Invoke-PolicyScenario -Name "non-release unchanged metadata" -HeadBranch "feature/tooling" -HeadVersion "1.0.0" -ShouldPass $true
Invoke-PolicyScenario -Name "non-release changed metadata" -HeadBranch "fix/version-text" -HeadVersion "1.1.0" -ShouldPass $false -ExpectedErrorContains "Non-release branch 'fix/version-text' changes public version metadata"
Invoke-PolicyScenario -Name "release changed metadata" -HeadBranch "release/v1.1.0" -HeadVersion "1.1.0" -RequireTrustedReleaseBranch -ShouldPass $true
Invoke-PolicyScenario -Name "fork release branch changed metadata" -HeadBranch "release/v1.1.0" -HeadVersion "1.1.0" -HeadRepositoryOwner "external-user" -RequireTrustedReleaseBranch -ShouldPass $false -ExpectedErrorContains "Release version changes must come from a release/* branch in the base repository"
Invoke-PolicyScenario -Name "non-release plugin cfg text change without version change" -HeadBranch "docs/plugin-metadata" -HeadVersion "1.0.0" -MutateHead { param($repo) Write-MetadataFixture -RepositoryRoot $repo -Version "1.0.0" -PluginDescription "Updated metadata" } -ShouldPass $true
Invoke-PolicyScenario -Name "non-release protocol version only" -HeadBranch "feature/protocol-version" -HeadVersion "1.0.0" -MutateHead { param($repo) $path = Join-Path $repo "addons\godot_dotnet_mcp\plugin\runtime\mcp_protocol_facts.json"; $content = Get-Content -LiteralPath $path -Raw -Encoding UTF8; $content = $content.Replace('"server_version": "1.0.0"', '"server_version": "1.1.0"'); Set-Content -LiteralPath $path -Value $content -Encoding UTF8 } -ShouldPass $false -ExpectedErrorContains "protocol facts server_version"
Invoke-PolicyScenario -Name "missing head version" -HeadBranch "feature/missing-version" -HeadVersion "1.0.0" -MutateHead { param($repo) $path = Join-Path $repo "addons\godot_dotnet_mcp\plugin.cfg"; $content = Get-Content -LiteralPath $path -Raw -Encoding UTF8; $content = $content -replace 'version="[^"]+"\r?\n', ''; Set-Content -LiteralPath $path -Value $content -Encoding UTF8 } -ShouldPass $false -ExpectedErrorContains "Cannot find plugin.cfg version"

Write-Host "Version policy scenarios validated successfully."
