param(
    [string]$ManifestPath = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ManifestPath)) {
    $repositoryRoot = Split-Path -Parent $PSScriptRoot
    $ManifestPath = Join-Path $repositoryRoot "addons\godot_dotnet_mcp\companion\contracts\v2-broker-manifest.json"
}

function Require-String {
    param($Object, [string]$Name, [string]$Context)

    if ($Object.PSObject.Properties.Name -notcontains $Name) {
        throw "$Context must declare '$Name'."
    }

    $value = $Object.$Name
    if ($value -isnot [string] -or [string]::IsNullOrWhiteSpace($value)) {
        throw "$Context '$Name' must be a non-empty string."
    }

    return $value
}

function Require-Bool {
    param($Object, [string]$Name, [string]$Context)

    if ($Object.PSObject.Properties.Name -notcontains $Name) {
        throw "$Context must declare '$Name'."
    }

    $value = $Object.$Name
    if ($value -isnot [bool]) {
        throw "$Context '$Name' must be a boolean."
    }

    return [bool]$value
}

function Assert-Bool {
    param([bool]$Actual, [bool]$Expected, [string]$Message)

    if ($Actual -ne $Expected) {
        throw $Message
    }
}

$resolvedManifestPath = Resolve-Path -LiteralPath $ManifestPath
$manifest = Get-Content -LiteralPath $resolvedManifestPath -Encoding UTF8 -Raw | ConvertFrom-Json

if ((Require-String -Object $manifest -Name "contract" -Context "manifest") -ne "godot-dotnet-mcp.v2.broker") {
    throw "Unexpected v2 broker manifest contract."
}

$lifecycle = $manifest.default_lifecycle
Assert-Bool -Actual (Require-Bool -Object $lifecycle -Name "enabled_by_default" -Context "default_lifecycle") -Expected $false -Message "Broker must be disabled by default."
Assert-Bool -Actual (Require-Bool -Object $lifecycle -Name "starts_background_process" -Context "default_lifecycle") -Expected $false -Message "Broker must not start a background process by default."
Assert-Bool -Actual (Require-Bool -Object $lifecycle -Name "opens_listening_port" -Context "default_lifecycle") -Expected $false -Message "Broker must not open a listening port by default."
Assert-Bool -Actual (Require-Bool -Object $lifecycle -Name "launches_godot_editor" -Context "default_lifecycle") -Expected $false -Message "Broker must not launch Godot by default."
Assert-Bool -Actual (Require-Bool -Object $lifecycle -Name "requires_explicit_start" -Context "default_lifecycle") -Expected $true -Message "Broker must require explicit start."
Assert-Bool -Actual (Require-Bool -Object $lifecycle -Name "requires_explicit_editor_launch" -Context "default_lifecycle") -Expected $true -Message "Broker must require explicit editor launch."

$discovery = $manifest.project_discovery
Assert-Bool -Actual (Require-Bool -Object $discovery -Name "scans_known_projects_only" -Context "project_discovery") -Expected $true -Message "Broker discovery must stay limited to known projects."
Assert-Bool -Actual (Require-Bool -Object $discovery -Name "allows_recursive_home_scan" -Context "project_discovery") -Expected $false -Message "Broker discovery must not allow recursive home scans."
Assert-Bool -Actual (Require-Bool -Object $discovery -Name "requires_explicit_project_registration" -Context "project_discovery") -Expected $true -Message "Broker discovery must require explicit project registration."

$transport = $manifest.transport
$allowedModes = @($transport.allowed_modes)
if ($allowedModes.Count -ne 2 -or $allowedModes -notcontains "stdio" -or $allowedModes -notcontains "http_loopback") {
    throw "Broker transport modes must be exactly stdio and http_loopback."
}

if ((Require-String -Object $transport -Name "default_mode" -Context "transport") -ne "stdio") {
    throw "Broker default transport must be stdio."
}

$httpLoopback = $transport.http_loopback
Assert-Bool -Actual (Require-Bool -Object $httpLoopback -Name "enabled_by_default" -Context "transport.http_loopback") -Expected $false -Message "HTTP loopback transport must be disabled by default."
if ((Require-String -Object $httpLoopback -Name "host" -Context "transport.http_loopback") -ne "127.0.0.1") {
    throw "HTTP loopback transport must be loopback-only."
}
Assert-Bool -Actual (Require-Bool -Object $httpLoopback -Name "requires_explicit_port" -Context "transport.http_loopback") -Expected $true -Message "HTTP loopback transport must require an explicit port."

$scope = $manifest.session_scope
Assert-Bool -Actual (Require-Bool -Object $scope -Name "requires_project_id" -Context "session_scope") -Expected $true -Message "Broker session tools must require project_id."
Assert-Bool -Actual (Require-Bool -Object $scope -Name "requires_session_id" -Context "session_scope") -Expected $true -Message "Broker session tools must require session_id."
Assert-Bool -Actual (Require-Bool -Object $scope -Name "rejects_cross_project_session" -Context "session_scope") -Expected $true -Message "Broker must reject cross-project session reuse."

Write-Host "v2 broker manifest validation passed: $resolvedManifestPath"
