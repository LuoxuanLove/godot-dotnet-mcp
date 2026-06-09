$ErrorActionPreference = "Stop"

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$validatorPath = Join-Path $repositoryRoot "scripts\validate_v2_broker_manifest.ps1"
$manifestPath = Join-Path $repositoryRoot "addons\godot_dotnet_mcp\companion\contracts\v2-broker-manifest.json"

function ConvertTo-JsonFile {
    param($Object, [string]$Path)
    $Object | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Copy-Manifest {
    param([string]$Path)
    $manifest = Get-Content -LiteralPath $manifestPath -Encoding UTF8 -Raw | ConvertFrom-Json
    ConvertTo-JsonFile -Object $manifest -Path $Path
    return Get-Content -LiteralPath $Path -Encoding UTF8 -Raw | ConvertFrom-Json
}

function Invoke-Validator {
    param([string]$Path)
    & $validatorPath -ManifestPath $Path | Out-Host
}

function Assert-Fails {
    param([string]$Name, [scriptblock]$Action)

    try {
        & $Action
    }
    catch {
        Write-Host "PASS $Name"
        return
    }

    throw "Expected validation failure: $Name"
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("godot-dotnet-mcp-v2-broker-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

try {
    Invoke-Validator -Path $manifestPath
    Write-Host "PASS valid_manifest"

    Assert-Fails "broker_cannot_be_enabled_by_default" {
        $path = Join-Path $tempRoot "enabled-default.json"
        $manifest = Copy-Manifest -Path $path
        $manifest.default_lifecycle.enabled_by_default = $true
        ConvertTo-JsonFile -Object $manifest -Path $path
        Invoke-Validator -Path $path
    }

    Assert-Fails "broker_cannot_start_background_process_by_default" {
        $path = Join-Path $tempRoot "background-process.json"
        $manifest = Copy-Manifest -Path $path
        $manifest.default_lifecycle.starts_background_process = $true
        ConvertTo-JsonFile -Object $manifest -Path $path
        Invoke-Validator -Path $path
    }

    Assert-Fails "broker_cannot_open_port_by_default" {
        $path = Join-Path $tempRoot "opens-port.json"
        $manifest = Copy-Manifest -Path $path
        $manifest.default_lifecycle.opens_listening_port = $true
        ConvertTo-JsonFile -Object $manifest -Path $path
        Invoke-Validator -Path $path
    }

    Assert-Fails "broker_cannot_launch_godot_by_default" {
        $path = Join-Path $tempRoot "launches-godot.json"
        $manifest = Copy-Manifest -Path $path
        $manifest.default_lifecycle.launches_godot_editor = $true
        ConvertTo-JsonFile -Object $manifest -Path $path
        Invoke-Validator -Path $path
    }

    Assert-Fails "broker_discovery_must_scan_known_projects_only" {
        $path = Join-Path $tempRoot "known-projects-only.json"
        $manifest = Copy-Manifest -Path $path
        $manifest.project_discovery.scans_known_projects_only = $false
        ConvertTo-JsonFile -Object $manifest -Path $path
        Invoke-Validator -Path $path
    }

    Assert-Fails "broker_cannot_scan_home_recursively" {
        $path = Join-Path $tempRoot "home-scan.json"
        $manifest = Copy-Manifest -Path $path
        $manifest.project_discovery.allows_recursive_home_scan = $true
        ConvertTo-JsonFile -Object $manifest -Path $path
        Invoke-Validator -Path $path
    }

    Assert-Fails "broker_requires_explicit_project_registration" {
        $path = Join-Path $tempRoot "implicit-registration.json"
        $manifest = Copy-Manifest -Path $path
        $manifest.project_discovery.requires_explicit_project_registration = $false
        ConvertTo-JsonFile -Object $manifest -Path $path
        Invoke-Validator -Path $path
    }

    Assert-Fails "http_loopback_cannot_be_default" {
        $path = Join-Path $tempRoot "http-default.json"
        $manifest = Copy-Manifest -Path $path
        $manifest.transport.default_mode = "http_loopback"
        ConvertTo-JsonFile -Object $manifest -Path $path
        Invoke-Validator -Path $path
    }

    Assert-Fails "http_loopback_cannot_be_enabled_by_default" {
        $path = Join-Path $tempRoot "http-enabled-default.json"
        $manifest = Copy-Manifest -Path $path
        $manifest.transport.http_loopback.enabled_by_default = $true
        ConvertTo-JsonFile -Object $manifest -Path $path
        Invoke-Validator -Path $path
    }

    Assert-Fails "http_loopback_must_stay_loopback_only" {
        $path = Join-Path $tempRoot "http-public.json"
        $manifest = Copy-Manifest -Path $path
        $manifest.transport.http_loopback.host = "0.0.0.0"
        ConvertTo-JsonFile -Object $manifest -Path $path
        Invoke-Validator -Path $path
    }

    Assert-Fails "http_loopback_requires_explicit_port" {
        $path = Join-Path $tempRoot "http-implicit-port.json"
        $manifest = Copy-Manifest -Path $path
        $manifest.transport.http_loopback.requires_explicit_port = $false
        ConvertTo-JsonFile -Object $manifest -Path $path
        Invoke-Validator -Path $path
    }

    Assert-Fails "broker_tools_require_project_scope" {
        $path = Join-Path $tempRoot "missing-project.json"
        $manifest = Copy-Manifest -Path $path
        $manifest.session_scope.requires_project_id = $false
        ConvertTo-JsonFile -Object $manifest -Path $path
        Invoke-Validator -Path $path
    }

    Assert-Fails "broker_tools_require_session_scope" {
        $path = Join-Path $tempRoot "missing-session.json"
        $manifest = Copy-Manifest -Path $path
        $manifest.session_scope.requires_session_id = $false
        ConvertTo-JsonFile -Object $manifest -Path $path
        Invoke-Validator -Path $path
    }

    Assert-Fails "broker_rejects_cross_project_session" {
        $path = Join-Path $tempRoot "cross-project-session.json"
        $manifest = Copy-Manifest -Path $path
        $manifest.session_scope.rejects_cross_project_session = $false
        ConvertTo-JsonFile -Object $manifest -Path $path
        Invoke-Validator -Path $path
    }
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
