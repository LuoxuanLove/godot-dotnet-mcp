$ErrorActionPreference = "Stop"

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$validatorPath = Join-Path $repositoryRoot "scripts\validate_v2_bridge_contract.ps1"
$schemaPath = Join-Path $repositoryRoot "companion\contracts\v2-bridge-status.schema.json"

function ConvertTo-JsonFile {
    param(
        [Parameter(Mandatory = $true)]$Object,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $Object | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Copy-Schema {
    param([Parameter(Mandatory = $true)][string]$Path)

    $schema = Get-Content -LiteralPath $schemaPath -Encoding UTF8 -Raw | ConvertFrom-Json
    ConvertTo-JsonFile -Object $schema -Path $Path
    return Get-Content -LiteralPath $Path -Encoding UTF8 -Raw | ConvertFrom-Json
}

function Invoke-Validator {
    param([Parameter(Mandatory = $true)][string]$Path)

    & $validatorPath -SchemaPath $Path | Out-Host
}

function Assert-Passes {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][scriptblock]$Action
    )

    & $Action
    Write-Host "PASS $Name"
}

function Assert-Fails {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][scriptblock]$Action
    )

    try {
        & $Action
    }
    catch {
        Write-Host "PASS $Name"
        return
    }

    throw "Expected validation failure: $Name"
}

function Assert-PatternAccepts {
    param(
        [Parameter(Mandatory = $true)][string]$Pattern,
        [Parameter(Mandatory = $true)][string]$Value
    )

    if (-not [regex]::IsMatch($Value, $Pattern)) {
        throw "Expected plugin_version pattern to accept '$Value'."
    }
}

function Assert-PatternRejects {
    param(
        [Parameter(Mandatory = $true)][string]$Pattern,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Value
    )

    if ([regex]::IsMatch($Value, $Pattern)) {
        throw "Expected plugin_version pattern to reject '$Value'."
    }
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("godot-dotnet-mcp-v2-bridge-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

try {
    Assert-Passes "valid_schema" {
        Invoke-Validator -Path $schemaPath
    }

    Assert-Passes "plugin_version_policy_samples" {
        $schema = Get-Content -LiteralPath $schemaPath -Encoding UTF8 -Raw | ConvertFrom-Json
        $pattern = $schema.properties.plugin_version.pattern
        foreach ($value in @("3.0.0", "v3.0.0", "3.0.0-preview.1", "3.0.0+build.5", "v3.0.0-preview.1+build.5")) {
            Assert-PatternAccepts -Pattern $pattern -Value $value
        }

        foreach ($value in @("", " 3.0.0", "3.0.0 ", "1.4.0", "2.0.0", "4.0.0", "03.0.0", "3.0.0-", "3.0.0+", "3.0.0-preview..1", "3.0.0+bad space")) {
            Assert-PatternRejects -Pattern $pattern -Value $value
        }
    }

    Assert-Fails "online_requires_editor_session_id" {
        $path = Join-Path $tempRoot "online-without-session.json"
        $schema = Copy-Schema -Path $path
        $onlineRule = @($schema.allOf) | Where-Object { $_.if.properties.state.const -eq "online" } | Select-Object -First 1
        $onlineRule.then.properties.editor_session_id.minLength = 0
        ConvertTo-JsonFile -Object $schema -Path $path
        Invoke-Validator -Path $path
    }

    Assert-Fails "offline_cannot_support_live_state" {
        $path = Join-Path $tempRoot "offline-live.json"
        $schema = Copy-Schema -Path $path
        $nonLiveRule = @($schema.allOf) | Where-Object { @($_.if.properties.state.enum) -contains "disabled" } | Select-Object -First 1
        $nonLiveRule.then.properties.supports_live_editor_state.const = $true
        ConvertTo-JsonFile -Object $schema -Path $path
        Invoke-Validator -Path $path
    }

    Assert-Fails "non_live_rule_must_cover_offline" {
        $path = Join-Path $tempRoot "missing-offline.json"
        $schema = Copy-Schema -Path $path
        $nonLiveRule = @($schema.allOf) | Where-Object { @($_.if.properties.state.enum) -contains "disabled" } | Select-Object -First 1
        $nonLiveRule.if.properties.state.enum = @("disabled", "version_mismatch")
        ConvertTo-JsonFile -Object $schema -Path $path
        Invoke-Validator -Path $path
    }

    Assert-Fails "non_live_rule_must_cover_version_mismatch" {
        $path = Join-Path $tempRoot "missing-version-mismatch.json"
        $schema = Copy-Schema -Path $path
        $nonLiveRule = @($schema.allOf) | Where-Object { @($_.if.properties.state.enum) -contains "disabled" } | Select-Object -First 1
        $nonLiveRule.if.properties.state.enum = @("disabled", "offline")
        ConvertTo-JsonFile -Object $schema -Path $path
        Invoke-Validator -Path $path
    }

    Assert-Fails "online_requires_plugin_version_string" {
        $path = Join-Path $tempRoot "online-plugin-version-null.json"
        $schema = Copy-Schema -Path $path
        $onlineRule = @($schema.allOf) | Where-Object { $_.if.properties.state.const -eq "online" } | Select-Object -First 1
        $onlineRule.then.properties.plugin_version.type = @("string", "null")
        ConvertTo-JsonFile -Object $schema -Path $path
        Invoke-Validator -Path $path
    }

    Assert-Fails "schema_rejects_extra_properties" {
        $path = Join-Path $tempRoot "extra-properties.json"
        $schema = Copy-Schema -Path $path
        $schema.additionalProperties = $true
        ConvertTo-JsonFile -Object $schema -Path $path
        Invoke-Validator -Path $path
    }
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
