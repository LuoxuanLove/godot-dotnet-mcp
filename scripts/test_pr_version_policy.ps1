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
  "protocol_version": "2025-11-25",
  "tool_schema_version": "2026-05-03.10",
  "server_name": "godot-dotnet-mcp",
  "server_description": "Godot editor MCP server for resource-first project context, automation, diagnostics, and validation.",
  "server_version": "$Version",
  "error_codes": {
    "invalid_argument": "invalid_argument",
    "runtime_not_running": "runtime_not_running"
  }
}
"@ | Set-Content -LiteralPath (Join-Path $RepositoryRoot $metadataFiles[1]) -Encoding UTF8

    @"
static func _default_facts() -> Dictionary:
`treturn {
`t`t"protocol_version": "2025-11-25",
`t`t"tool_schema_version": "2026-05-03.10",
`t`t"server_name": "godot-dotnet-mcp",
`t`t"server_description": "Godot editor MCP server for resource-first project context, automation, diagnostics, and validation.",
`t`t"server_version": "$Version",
`t`t"error_codes": {
`t`t`t"invalid_argument": "invalid_argument",
`t`t`t"runtime_not_running": "runtime_not_running"
`t`t}
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
        [string]$ComparisonBaseVersion = "",
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

    if (-not [string]::IsNullOrWhiteSpace($ComparisonBaseVersion)) {
        git -C $repo switch -c refactor/v1.4.0 -q
        Write-MetadataFixture -RepositoryRoot $repo -Version $ComparisonBaseVersion -PluginDescription "Comparison base fixture"
        git -C $repo add addons
        git -C $repo commit -m "comparison base" -q
    }

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
        [string]$BaseBranch = "dev",
        [string]$BaseVersion = "1.0.0",
        [string]$ComparisonBaseVersion = "",
        [string]$HeadVersion = "1.0.0",
        [scriptblock]$MutateHead = $null,
        [bool]$ShouldPass,
        [string]$RepositoryOwner = "LuoxuanLove",
        [string]$HeadRepositoryOwner = "LuoxuanLove",
        [string]$ExpectedErrorContains = "",
        [switch]$RequireTrustedReleaseBranch
    )

    $repo = New-PolicyFixture -BaseVersion $BaseVersion -ComparisonBaseVersion $ComparisonBaseVersion -HeadVersion $HeadVersion -HeadBranch $HeadBranch -MutateHead $MutateHead
    try {
        $headCommit = (git -C $repo rev-parse HEAD).Trim()
        $baseRef = if ([string]::IsNullOrWhiteSpace($ComparisonBaseVersion)) { "dev" } else { $BaseBranch }
        $passed = $true
        $failureMessage = ""
        try {
            & $validatorPath -RepositoryRoot $repo -BaseBranch $BaseBranch -HeadBranch $HeadBranch -BaseRef $baseRef -HeadRef $headCommit -RepositoryOwner $RepositoryOwner -HeadRepositoryOwner $HeadRepositoryOwner -RequireTrustedReleaseBranch:$RequireTrustedReleaseBranch -SkipFetch | Out-Host
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
Invoke-PolicyScenario -Name "refactor base unchanged metadata" -BaseBranch "refactor/v1.4.0" -HeadBranch "feature/v1.4-tooling" -HeadVersion "1.0.0" -ShouldPass $true
Invoke-PolicyScenario -Name "refactor base compares against refactor ref, not default branch checkout" -BaseBranch "refactor/v1.4.0" -BaseVersion "1.3.0" -ComparisonBaseVersion "1.4.0" -HeadBranch "feature/v1.4-policy" -HeadVersion "1.4.0" -ShouldPass $true
Invoke-PolicyScenario -Name "v2.0 refactor base unchanged metadata" -BaseBranch "refactor/v2.0.0" -HeadBranch "feature/v2.0-tooling" -HeadVersion "1.0.0" -ShouldPass $true
Invoke-PolicyScenario -Name "non-release changed metadata" -HeadBranch "fix/version-text" -HeadVersion "1.1.0" -ShouldPass $false -ExpectedErrorContains "Non-release branch 'fix/version-text' changes public version metadata"
Invoke-PolicyScenario -Name "refactor base changed metadata" -BaseBranch "refactor/v1.4.0" -HeadBranch "feature/v1.4-version" -HeadVersion "1.1.0" -ShouldPass $false -ExpectedErrorContains "Non-release branch 'feature/v1.4-version' changes public version metadata"
Invoke-PolicyScenario -Name "refactor base catches drift from comparison base" -BaseBranch "refactor/v1.4.0" -BaseVersion "1.3.0" -ComparisonBaseVersion "1.4.0" -HeadBranch "feature/v1.4-version-drift" -HeadVersion "1.4.1" -ShouldPass $false -ExpectedErrorContains "Non-release branch 'feature/v1.4-version-drift' changes public version metadata"
Invoke-PolicyScenario -Name "v1.4 refactor baseline changed metadata" -BaseBranch "refactor/v1.4.0" -HeadBranch "chore/v1.4-version-baseline" -HeadVersion "1.4.0" -RequireTrustedReleaseBranch -ShouldPass $true
Invoke-PolicyScenario -Name "fork v1.4 refactor baseline changed metadata" -BaseBranch "refactor/v1.4.0" -HeadBranch "chore/v1.4-version-baseline" -HeadVersion "1.4.0" -HeadRepositoryOwner "external-user" -RequireTrustedReleaseBranch -ShouldPass $false -ExpectedErrorContains "v1.4 refactor baseline version changes must come from the base repository"
Invoke-PolicyScenario -Name "v2.0 migration from v1.4 refactor changed metadata" -BaseBranch "refactor/v1.4.0" -HeadBranch "refactor/v2.0.0" -HeadVersion "2.0.0" -RequireTrustedReleaseBranch -ShouldPass $true
Invoke-PolicyScenario -Name "fork v2.0 migration from v1.4 refactor changed metadata" -BaseBranch "refactor/v1.4.0" -HeadBranch "refactor/v2.0.0" -HeadVersion "2.0.0" -HeadRepositoryOwner "external-user" -RequireTrustedReleaseBranch -ShouldPass $false -ExpectedErrorContains "v2.0 refactor migration version changes must come from the base repository"
Invoke-PolicyScenario -Name "v1.4 refactor integration to dev changed metadata" -BaseBranch "dev" -HeadBranch "refactor/v1.4.0" -HeadVersion "1.4.0" -RequireTrustedReleaseBranch -ShouldPass $true
Invoke-PolicyScenario -Name "fork v1.4 refactor integration to dev changed metadata" -BaseBranch "dev" -HeadBranch "refactor/v1.4.0" -HeadVersion "1.4.0" -HeadRepositoryOwner "external-user" -RequireTrustedReleaseBranch -ShouldPass $false -ExpectedErrorContains "v1.4 refactor integration version changes must come from the base repository"
Invoke-PolicyScenario -Name "v2.0 refactor integration to dev changed metadata" -BaseBranch "dev" -HeadBranch "refactor/v2.0.0" -HeadVersion "2.0.0" -RequireTrustedReleaseBranch -ShouldPass $true
Invoke-PolicyScenario -Name "fork v2.0 refactor integration to dev changed metadata" -BaseBranch "dev" -HeadBranch "refactor/v2.0.0" -HeadVersion "2.0.0" -HeadRepositoryOwner "external-user" -RequireTrustedReleaseBranch -ShouldPass $false -ExpectedErrorContains "v2.0 refactor integration version changes must come from the base repository"
Invoke-PolicyScenario -Name "release changed metadata" -HeadBranch "release/v1.1.0" -HeadVersion "1.1.0" -RequireTrustedReleaseBranch -ShouldPass $true
Invoke-PolicyScenario -Name "release branch cannot target refactor base" -BaseBranch "refactor/v1.4.0" -HeadBranch "release/v1.1.0" -HeadVersion "1.1.0" -RequireTrustedReleaseBranch -ShouldPass $false -ExpectedErrorContains "Release version changes must target dev"
Invoke-PolicyScenario -Name "fork release branch changed metadata" -HeadBranch "release/v1.1.0" -HeadVersion "1.1.0" -HeadRepositoryOwner "external-user" -RequireTrustedReleaseBranch -ShouldPass $false -ExpectedErrorContains "Release version changes must come from a release/* branch in the base repository"
Invoke-PolicyScenario -Name "non-release plugin cfg text change without version change" -HeadBranch "docs/plugin-metadata" -HeadVersion "1.0.0" -MutateHead { param($repo) Write-MetadataFixture -RepositoryRoot $repo -Version "1.0.0" -PluginDescription "Updated metadata" } -ShouldPass $true
Invoke-PolicyScenario -Name "non-release protocol version only" -HeadBranch "feature/protocol-version" -HeadVersion "1.0.0" -MutateHead { param($repo) $path = Join-Path $repo "addons\godot_dotnet_mcp\plugin\runtime\mcp_protocol_facts.json"; $content = Get-Content -LiteralPath $path -Raw -Encoding UTF8; $content = $content.Replace('"server_version": "1.0.0"', '"server_version": "1.1.0"'); Set-Content -LiteralPath $path -Value $content -Encoding UTF8 } -ShouldPass $false -ExpectedErrorContains "Protocol facts parity failed for head server_version"
Invoke-PolicyScenario -Name "protocol schema fallback drift" -HeadBranch "feature/protocol-schema-drift" -HeadVersion "1.0.0" -MutateHead { param($repo) $path = Join-Path $repo "addons\godot_dotnet_mcp\plugin\runtime\mcp_protocol_facts.gd"; $content = Get-Content -LiteralPath $path -Raw -Encoding UTF8; $content = $content.Replace('"tool_schema_version": "2026-05-03.10"', '"tool_schema_version": "2026-05-03.11"'); Set-Content -LiteralPath $path -Value $content -Encoding UTF8 } -ShouldPass $false -ExpectedErrorContains "Protocol facts parity failed for head tool_schema_version"
Invoke-PolicyScenario -Name "protocol description fallback drift" -HeadBranch "feature/protocol-description-drift" -HeadVersion "1.0.0" -MutateHead { param($repo) $path = Join-Path $repo "addons\godot_dotnet_mcp\plugin\runtime\mcp_protocol_facts.gd"; $content = Get-Content -LiteralPath $path -Raw -Encoding UTF8; $content = $content.Replace('"server_description": "Godot editor MCP server for resource-first project context, automation, diagnostics, and validation."', '"server_description": "Drifted description"'); Set-Content -LiteralPath $path -Value $content -Encoding UTF8 } -ShouldPass $false -ExpectedErrorContains "Protocol facts parity failed for head server_description"
Invoke-PolicyScenario -Name "protocol fallback missing error code" -HeadBranch "feature/protocol-error-code-drift" -HeadVersion "1.0.0" -MutateHead { param($repo) $path = Join-Path $repo "addons\godot_dotnet_mcp\plugin\runtime\mcp_protocol_facts.gd"; $content = Get-Content -LiteralPath $path -Raw -Encoding UTF8; $content = $content.Replace("`r`n`t`t`t`"invalid_argument`": `"invalid_argument`",", ""); $content = $content.Replace("`n`t`t`t`"invalid_argument`": `"invalid_argument`",", ""); Set-Content -LiteralPath $path -Value $content -Encoding UTF8 } -ShouldPass $false -ExpectedErrorContains "fallback is missing key(s): invalid_argument"
Invoke-PolicyScenario -Name "protocol fallback error code value drift" -HeadBranch "feature/protocol-error-code-value-drift" -HeadVersion "1.0.0" -MutateHead { param($repo) $path = Join-Path $repo "addons\godot_dotnet_mcp\plugin\runtime\mcp_protocol_facts.gd"; $content = Get-Content -LiteralPath $path -Raw -Encoding UTF8; $content = $content.Replace('"invalid_argument": "invalid_argument"', '"invalid_argument": "invalid_arg"'); Set-Content -LiteralPath $path -Value $content -Encoding UTF8 } -ShouldPass $false -ExpectedErrorContains "Protocol facts parity failed for head error_codes.invalid_argument"
Invoke-PolicyScenario -Name "missing head version" -HeadBranch "feature/missing-version" -HeadVersion "1.0.0" -MutateHead { param($repo) $path = Join-Path $repo "addons\godot_dotnet_mcp\plugin.cfg"; $content = Get-Content -LiteralPath $path -Raw -Encoding UTF8; $content = $content -replace 'version="[^"]+"\r?\n', ''; Set-Content -LiteralPath $path -Value $content -Encoding UTF8 } -ShouldPass $false -ExpectedErrorContains "Cannot find plugin.cfg version"

Write-Host "Version policy scenarios validated successfully."
