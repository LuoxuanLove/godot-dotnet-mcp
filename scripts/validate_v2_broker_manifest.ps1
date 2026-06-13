param(
    [string]$ManifestPath = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ManifestPath)) {
    $repositoryRoot = Split-Path -Parent $PSScriptRoot
    $ManifestPath = Join-Path $repositoryRoot "companion\contracts\v2-broker-manifest.json"
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

function Require-PositiveInteger {
    param($Object, [string]$Name, [string]$Context)

    if ($Object.PSObject.Properties.Name -notcontains $Name) {
        throw "$Context must declare '$Name'."
    }

    $value = $Object.$Name
    if ($value -isnot [int] -and $value -isnot [long]) {
        throw "$Context '$Name' must be an integer."
    }

    $number = [int64]$value
    if ($number -le 0) {
        throw "$Context '$Name' must be positive."
    }

    return $number
}

function Assert-Bool {
    param([bool]$Actual, [bool]$Expected, [string]$Message)

    if ($Actual -ne $Expected) {
        throw $Message
    }
}

$brokerLifecycleContract = [ordered]@{
    enabled_by_default = $false
    starts_background_process = $false
    opens_listening_port = $false
    launches_godot_editor = $false
    requires_explicit_start = $true
    requires_explicit_editor_launch = $true
}

$resolvedManifestPath = Resolve-Path -LiteralPath $ManifestPath
$manifest = Get-Content -LiteralPath $resolvedManifestPath -Encoding UTF8 -Raw | ConvertFrom-Json

if ((Require-String -Object $manifest -Name "contract" -Context "manifest") -ne "godot-dotnet-mcp.v2.broker") {
    throw "Unexpected v2 broker manifest contract."
}

$lifecycle = $manifest.default_lifecycle
Assert-Bool -Actual (Require-Bool -Object $lifecycle -Name "enabled_by_default" -Context "default_lifecycle") -Expected $brokerLifecycleContract.enabled_by_default -Message "Broker must be disabled by default."
Assert-Bool -Actual (Require-Bool -Object $lifecycle -Name "starts_background_process" -Context "default_lifecycle") -Expected $brokerLifecycleContract.starts_background_process -Message "Broker must not start a background process by default."
Assert-Bool -Actual (Require-Bool -Object $lifecycle -Name "opens_listening_port" -Context "default_lifecycle") -Expected $brokerLifecycleContract.opens_listening_port -Message "Broker must not open a listening port by default."
Assert-Bool -Actual (Require-Bool -Object $lifecycle -Name "launches_godot_editor" -Context "default_lifecycle") -Expected $brokerLifecycleContract.launches_godot_editor -Message "Broker must not launch Godot by default."
Assert-Bool -Actual (Require-Bool -Object $lifecycle -Name "requires_explicit_start" -Context "default_lifecycle") -Expected $brokerLifecycleContract.requires_explicit_start -Message "Broker must require explicit start."
Assert-Bool -Actual (Require-Bool -Object $lifecycle -Name "requires_explicit_editor_launch" -Context "default_lifecycle") -Expected $brokerLifecycleContract.requires_explicit_editor_launch -Message "Broker must require explicit editor launch."
Assert-Bool -Actual (Require-Bool -Object $lifecycle -Name "validated_by_runtime_contract" -Context "default_lifecycle") -Expected $true -Message "Broker default lifecycle must be backed by a runtime contract."

$discovery = $manifest.project_discovery
Assert-Bool -Actual (Require-Bool -Object $discovery -Name "scans_known_projects_only" -Context "project_discovery") -Expected $true -Message "Broker discovery must stay limited to known projects."
Assert-Bool -Actual (Require-Bool -Object $discovery -Name "allows_recursive_home_scan" -Context "project_discovery") -Expected $false -Message "Broker discovery must not allow recursive home scans."
Assert-Bool -Actual (Require-Bool -Object $discovery -Name "requires_explicit_project_registration" -Context "project_discovery") -Expected $true -Message "Broker discovery must require explicit project registration."

$projectRegistry = $manifest.project_registry
Assert-Bool -Actual (Require-Bool -Object $projectRegistry -Name "lists_registered_projects" -Context "project_registry") -Expected $true -Message "Broker project registry must list explicitly registered projects."
Assert-Bool -Actual (Require-Bool -Object $projectRegistry -Name "reports_active_session_counts" -Context "project_registry") -Expected $true -Message "Broker project registry must report active session counts."
Assert-Bool -Actual (Require-Bool -Object $projectRegistry -Name "reports_session_mode_counts" -Context "project_registry") -Expected $true -Message "Broker project registry must report session mode counts."
Assert-Bool -Actual (Require-Bool -Object $projectRegistry -Name "reports_project_file_scope" -Context "project_registry") -Expected $true -Message "Broker project registry must report explicit project file scope."
Assert-Bool -Actual (Require-Bool -Object $projectRegistry -Name "list_projects_renews_sessions" -Context "project_registry") -Expected $false -Message "Broker project listing must not renew session leases."
Assert-Bool -Actual (Require-Bool -Object $projectRegistry -Name "list_projects_scans_filesystem" -Context "project_registry") -Expected $false -Message "Broker project listing must not scan the filesystem."

$brokerStatus = $manifest.broker_status
Assert-Bool -Actual (Require-Bool -Object $brokerStatus -Name "snapshot_supported" -Context "broker_status") -Expected $true -Message "Broker status snapshots must be supported."
Assert-Bool -Actual (Require-Bool -Object $brokerStatus -Name "snapshot_renews_sessions" -Context "broker_status") -Expected $false -Message "Broker status snapshots must not renew session leases."
Assert-Bool -Actual (Require-Bool -Object $brokerStatus -Name "snapshot_scans_filesystem" -Context "broker_status") -Expected $false -Message "Broker status snapshots must not scan the filesystem."
Assert-Bool -Actual (Require-Bool -Object $brokerStatus -Name "snapshot_launches_godot_editor" -Context "broker_status") -Expected $false -Message "Broker status snapshots must not launch Godot."
Assert-Bool -Actual (Require-Bool -Object $brokerStatus -Name "reports_registered_project_count" -Context "broker_status") -Expected $true -Message "Broker status snapshots must report registered project counts."
Assert-Bool -Actual (Require-Bool -Object $brokerStatus -Name "reports_session_mode_counts" -Context "broker_status") -Expected $true -Message "Broker status snapshots must report session mode counts."
Assert-Bool -Actual (Require-Bool -Object $brokerStatus -Name "reports_bridge_status_counts" -Context "broker_status") -Expected $true -Message "Broker status snapshots must report bridge status counts."
Assert-Bool -Actual (Require-Bool -Object $brokerStatus -Name "reports_project_summaries" -Context "broker_status") -Expected $true -Message "Broker status snapshots must report project summaries."

$brokerShutdown = $manifest.broker_shutdown
Assert-Bool -Actual (Require-Bool -Object $brokerShutdown -Name "explicit_shutdown_supported" -Context "broker_shutdown") -Expected $true -Message "Broker shutdown must be explicitly supported."
Assert-Bool -Actual (Require-Bool -Object $brokerShutdown -Name "shutdown_revokes_sessions" -Context "broker_shutdown") -Expected $true -Message "Broker shutdown must revoke project sessions."
Assert-Bool -Actual (Require-Bool -Object $brokerShutdown -Name "shutdown_clears_bridge_status" -Context "broker_shutdown") -Expected $true -Message "Broker shutdown must clear stored bridge status."
Assert-Bool -Actual (Require-Bool -Object $brokerShutdown -Name "shutdown_removes_registered_projects" -Context "broker_shutdown") -Expected $false -Message "Broker shutdown must not remove registered projects."
Assert-Bool -Actual (Require-Bool -Object $brokerShutdown -Name "shutdown_scans_filesystem" -Context "broker_shutdown") -Expected $false -Message "Broker shutdown must not scan the filesystem."
Assert-Bool -Actual (Require-Bool -Object $brokerShutdown -Name "shutdown_launches_godot_editor" -Context "broker_shutdown") -Expected $false -Message "Broker shutdown must not launch Godot."
Assert-Bool -Actual (Require-Bool -Object $brokerShutdown -Name "reports_revoked_session_count" -Context "broker_shutdown") -Expected $true -Message "Broker shutdown must report revoked session counts."
Assert-Bool -Actual (Require-Bool -Object $brokerShutdown -Name "reports_cleared_bridge_status_count" -Context "broker_shutdown") -Expected $true -Message "Broker shutdown must report cleared bridge status counts."

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
$httpPortMin = Require-PositiveInteger -Object $httpLoopback -Name "port_min" -Context "transport.http_loopback"
$httpPortMax = Require-PositiveInteger -Object $httpLoopback -Name "port_max" -Context "transport.http_loopback"
if ($httpPortMin -ne 1 -or $httpPortMax -ne 65535) {
    throw "HTTP loopback transport port range must be 1 through 65535."
}

$scope = $manifest.session_scope
Assert-Bool -Actual (Require-Bool -Object $scope -Name "requires_project_id" -Context "session_scope") -Expected $true -Message "Broker session tools must require project_id."
Assert-Bool -Actual (Require-Bool -Object $scope -Name "requires_session_id" -Context "session_scope") -Expected $true -Message "Broker session tools must require session_id."
Assert-Bool -Actual (Require-Bool -Object $scope -Name "rejects_cross_project_session" -Context "session_scope") -Expected $true -Message "Broker must reject cross-project session reuse."
Assert-Bool -Actual (Require-Bool -Object $scope -Name "reports_structured_validation" -Context "session_scope") -Expected $true -Message "Broker must expose structured session-scope validation."
$expectedReasonCodes = @(
    "accepted",
    "missing_project_id",
    "missing_session_id",
    "unknown_session_id",
    "project_session_mismatch",
    "expired_session",
    "inactive_session",
    "capability_unavailable"
)
$actualReasonCodes = @($scope.validation_reason_codes | ForEach-Object { [string]$_ })
if ($actualReasonCodes.Count -ne $expectedReasonCodes.Count) {
    throw "Broker session_scope validation_reason_codes must list the exact structured validation reasons."
}
foreach ($reasonCode in $expectedReasonCodes) {
    if ($actualReasonCodes -notcontains $reasonCode) {
        throw "Broker session_scope validation_reason_codes is missing '$reasonCode'."
    }
}
foreach ($reasonCode in $actualReasonCodes) {
    if ($expectedReasonCodes -notcontains $reasonCode) {
        throw "Broker session_scope validation_reason_codes contains unexpected '$reasonCode'."
    }
}

$sessionHealth = $manifest.session_health
Assert-Bool -Actual (Require-Bool -Object $sessionHealth -Name "snapshot_supported" -Context "session_health") -Expected $true -Message "Broker session health snapshots must be supported."
Assert-Bool -Actual (Require-Bool -Object $sessionHealth -Name "snapshot_renews_sessions" -Context "session_health") -Expected $false -Message "Broker session health snapshots must not renew session leases."
Assert-Bool -Actual (Require-Bool -Object $sessionHealth -Name "requires_project_id" -Context "session_health") -Expected $true -Message "Broker session health snapshots must require project_id."
Assert-Bool -Actual (Require-Bool -Object $sessionHealth -Name "requires_session_id" -Context "session_health") -Expected $true -Message "Broker session health snapshots must require session_id."
Assert-Bool -Actual (Require-Bool -Object $sessionHealth -Name "reports_bridge_status" -Context "session_health") -Expected $true -Message "Broker session health snapshots must report bridge status."
Assert-Bool -Actual (Require-Bool -Object $sessionHealth -Name "reports_editor_live_upgrade_eligibility" -Context "session_health") -Expected $true -Message "Broker session health snapshots must report editor-live upgrade eligibility."
Assert-Bool -Actual (Require-Bool -Object $sessionHealth -Name "reports_current_capabilities" -Context "session_health") -Expected $true -Message "Broker session health snapshots must report current capabilities."
Assert-Bool -Actual (Require-Bool -Object $sessionHealth -Name "rejects_cross_project_session" -Context "session_health") -Expected $true -Message "Broker session health snapshots must reject cross-project session reuse."

$sessionLifecycle = $manifest.session_lifecycle
$defaultLeaseMinutes = Require-PositiveInteger -Object $sessionLifecycle -Name "default_lease_minutes" -Context "session_lifecycle"
$maxActiveSessions = Require-PositiveInteger -Object $sessionLifecycle -Name "max_active_sessions" -Context "session_lifecycle"
$maxActiveSessionsPerProject = Require-PositiveInteger -Object $sessionLifecycle -Name "max_active_sessions_per_project" -Context "session_lifecycle"
if ($defaultLeaseMinutes -ne 30) {
    throw "Broker default session lease must stay 30 minutes."
}
if ($maxActiveSessions -ne 256) {
    throw "Broker global active session limit must stay 256."
}
if ($maxActiveSessionsPerProject -ne 32) {
    throw "Broker per-project active session limit must stay 32."
}
if ($maxActiveSessionsPerProject -gt $maxActiveSessions) {
    throw "Broker per-project active session limit cannot exceed the global limit."
}
Assert-Bool -Actual (Require-Bool -Object $sessionLifecycle -Name "tool_calls_renew_lease" -Context "session_lifecycle") -Expected $true -Message "Broker tool calls must renew active session leases."
Assert-Bool -Actual (Require-Bool -Object $sessionLifecycle -Name "renew_requires_active_session" -Context "session_lifecycle") -Expected $true -Message "Broker renew must require an active session."
Assert-Bool -Actual (Require-Bool -Object $sessionLifecycle -Name "stop_revokes_session" -Context "session_lifecycle") -Expected $true -Message "Broker stop must revoke the session."
Assert-Bool -Actual (Require-Bool -Object $sessionLifecycle -Name "expired_sessions_rejected" -Context "session_lifecycle") -Expected $true -Message "Broker must reject expired sessions."
Assert-Bool -Actual (Require-Bool -Object $sessionLifecycle -Name "expired_sessions_removed" -Context "session_lifecycle") -Expected $true -Message "Broker must remove expired sessions."

Write-Host "v2 broker manifest validation passed: $resolvedManifestPath"
