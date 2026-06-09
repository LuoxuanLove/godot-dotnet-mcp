$ErrorActionPreference = "Stop"

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$validatorPath = Join-Path $repositoryRoot "scripts\validate_v2_capability_manifest.ps1"
$manifestPath = Join-Path $repositoryRoot "addons\godot_dotnet_mcp\companion\contracts\v2-capabilities.json"

function ConvertTo-JsonFile {
    param(
        [Parameter(Mandatory = $true)]$Object,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $Object | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Copy-Manifest {
    param([Parameter(Mandatory = $true)][string]$Path)

    $manifest = Get-Content -LiteralPath $manifestPath -Encoding UTF8 -Raw | ConvertFrom-Json
    ConvertTo-JsonFile -Object $manifest -Path $Path
    return Get-Content -LiteralPath $Path -Encoding UTF8 -Raw | ConvertFrom-Json
}

function Invoke-Validator {
    param([Parameter(Mandatory = $true)][string]$Path)

    & $validatorPath -ManifestPath $Path | Out-Host
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

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("godot-dotnet-mcp-v2-capabilities-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

try {
    Assert-Passes "valid_manifest" {
        Invoke-Validator -Path $manifestPath
    }

    Assert-Fails "static_headless_cannot_claim_live_state" {
        $path = Join-Path $tempRoot "static-live-state.json"
        $manifest = Copy-Manifest -Path $path
        $manifest.capabilities[0].provides_live_editor_state = $true
        ConvertTo-JsonFile -Object $manifest -Path $path
        Invoke-Validator -Path $path
    }

    Assert-Fails "static_headless_cannot_smuggle_editor_capability_name" {
        $path = Join-Path $tempRoot "static-editor-name.json"
        $manifest = Copy-Manifest -Path $path
        $manifest.capabilities[0].id = "editor_selection"
        ConvertTo-JsonFile -Object $manifest -Path $path
        Invoke-Validator -Path $path
    }

    Assert-Fails "unknown_mode_cannot_bypass_editor_live_policy" {
        $path = Join-Path $tempRoot "unknown-live-mode.json"
        $manifest = Copy-Manifest -Path $path
        $manifest.modes = @($manifest.modes) + [pscustomobject]@{
            id = "live_preview"
            requires_editor_bridge = $false
            requires_explicit_upgrade = $false
            provides_live_editor_state = $true
            default_enabled = $true
        }
        $manifest.capabilities[0].mode = "live_preview"
        ConvertTo-JsonFile -Object $manifest -Path $path
        Invoke-Validator -Path $path
    }

    Assert-Fails "editor_live_requires_explicit_upgrade" {
        $path = Join-Path $tempRoot "editor-live-no-upgrade.json"
        $manifest = Copy-Manifest -Path $path
        $manifest.capabilities[-1].requires_explicit_upgrade = $false
        ConvertTo-JsonFile -Object $manifest -Path $path
        Invoke-Validator -Path $path
    }

    Assert-Fails "default_lifecycle_cannot_open_port" {
        $path = Join-Path $tempRoot "default-port.json"
        $manifest = Copy-Manifest -Path $path
        $manifest.default_lifecycle.opens_listening_port = $true
        ConvertTo-JsonFile -Object $manifest -Path $path
        Invoke-Validator -Path $path
    }

    Assert-Fails "capabilities_require_project_and_session_scope" {
        $path = Join-Path $tempRoot "missing-session-scope.json"
        $manifest = Copy-Manifest -Path $path
        $manifest.capabilities[0].requires_session_id = $false
        ConvertTo-JsonFile -Object $manifest -Path $path
        Invoke-Validator -Path $path
    }
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
