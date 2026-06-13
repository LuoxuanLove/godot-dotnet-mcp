param(
    [string]$ManifestPath = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ManifestPath)) {
    $repositoryRoot = Split-Path -Parent $PSScriptRoot
    $ManifestPath = Join-Path $repositoryRoot "companion\contracts\v2-capabilities.json"
}

function Test-HasProperty {
    param(
        [Parameter(Mandatory = $true)]$Object,
        [Parameter(Mandatory = $true)][string]$Name
    )

    return $Object.PSObject.Properties.Name -contains $Name
}

function Get-RequiredString {
    param(
        [Parameter(Mandatory = $true)]$Object,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Context
    )

    if (-not (Test-HasProperty -Object $Object -Name $Name)) {
        throw "$Context must declare '$Name'."
    }

    $value = $Object.$Name
    if ($value -isnot [string] -or [string]::IsNullOrWhiteSpace($value)) {
        throw "$Context '$Name' must be a non-empty string."
    }

    return $value
}

function Get-RequiredBool {
    param(
        [Parameter(Mandatory = $true)]$Object,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Context
    )

    if (-not (Test-HasProperty -Object $Object -Name $Name)) {
        throw "$Context must declare '$Name'."
    }

    $value = $Object.$Name
    if ($value -isnot [bool]) {
        throw "$Context '$Name' must be a boolean."
    }

    return [bool]$value
}

function Assert-Bool {
    param(
        [Parameter(Mandatory = $true)][bool]$Actual,
        [Parameter(Mandatory = $true)][bool]$Expected,
        [Parameter(Mandatory = $true)][string]$Message
    )

    if ($Actual -ne $Expected) {
        throw $Message
    }
}

$resolvedManifestPath = Resolve-Path -LiteralPath $ManifestPath
$manifest = Get-Content -LiteralPath $resolvedManifestPath -Encoding UTF8 -Raw | ConvertFrom-Json

$contract = Get-RequiredString -Object $manifest -Name "contract" -Context "manifest"
if ($contract -ne "godot-dotnet-mcp.v2.capabilities") {
    throw "Unexpected v2 capability manifest contract '$contract'."
}

if (-not (Test-HasProperty -Object $manifest -Name "tool_scope")) {
    throw "manifest must declare tool_scope."
}

Assert-Bool `
    -Actual (Get-RequiredBool -Object $manifest.tool_scope -Name "requires_project_id" -Context "tool_scope") `
    -Expected $true `
    -Message "v2 tools must require project_id."
Assert-Bool `
    -Actual (Get-RequiredBool -Object $manifest.tool_scope -Name "requires_session_id" -Context "tool_scope") `
    -Expected $true `
    -Message "v2 tools must require session_id."

if (-not (Test-HasProperty -Object $manifest -Name "default_lifecycle")) {
    throw "manifest must declare default_lifecycle."
}

$defaultLifecycle = $manifest.default_lifecycle
Assert-Bool `
    -Actual (Get-RequiredBool -Object $defaultLifecycle -Name "starts_background_process" -Context "default_lifecycle") `
    -Expected $false `
    -Message "The v2 companion must not start a background process by default."
Assert-Bool `
    -Actual (Get-RequiredBool -Object $defaultLifecycle -Name "opens_listening_port" -Context "default_lifecycle") `
    -Expected $false `
    -Message "The v2 companion must not open a listening port by default."
Assert-Bool `
    -Actual (Get-RequiredBool -Object $defaultLifecycle -Name "launches_godot_editor" -Context "default_lifecycle") `
    -Expected $false `
    -Message "The v2 companion must not launch the Godot editor by default."
Assert-Bool `
    -Actual (Get-RequiredBool -Object $defaultLifecycle -Name "requires_explicit_start" -Context "default_lifecycle") `
    -Expected $true `
    -Message "The v2 companion must require explicit start."
Assert-Bool `
    -Actual (Get-RequiredBool -Object $defaultLifecycle -Name "requires_explicit_editor_upgrade" -Context "default_lifecycle") `
    -Expected $true `
    -Message "The v2 companion must require explicit editor-live upgrade."

$modes = @($manifest.modes)
if ($modes.Count -eq 0) {
    throw "manifest must declare at least one mode."
}

$allowedModeIds = @{
    "static_headless" = $true
    "editor_live" = $true
}
$modeById = @{}
foreach ($mode in $modes) {
    $modeId = Get-RequiredString -Object $mode -Name "id" -Context "mode"
    if (-not $allowedModeIds.ContainsKey($modeId)) {
        throw "Unknown mode id '$modeId'. Add an explicit validator policy before declaring a new v2 capability mode."
    }

    if ($modeById.ContainsKey($modeId)) {
        throw "Duplicate mode id '$modeId'."
    }

    $modeById[$modeId] = $mode
}

foreach ($requiredMode in @("static_headless", "editor_live")) {
    if (-not $modeById.ContainsKey($requiredMode)) {
        throw "manifest must declare mode '$requiredMode'."
    }
}

$staticMode = $modeById["static_headless"]
Assert-Bool -Actual (Get-RequiredBool -Object $staticMode -Name "requires_editor_bridge" -Context "mode static_headless") -Expected $false -Message "static_headless must not require an editor bridge."
Assert-Bool -Actual (Get-RequiredBool -Object $staticMode -Name "requires_explicit_upgrade" -Context "mode static_headless") -Expected $false -Message "static_headless must not require editor-live upgrade."
Assert-Bool -Actual (Get-RequiredBool -Object $staticMode -Name "provides_live_editor_state" -Context "mode static_headless") -Expected $false -Message "static_headless must not provide live editor state."
Assert-Bool -Actual (Get-RequiredBool -Object $staticMode -Name "default_enabled" -Context "mode static_headless") -Expected $true -Message "static_headless must be the default mode."

$editorLiveMode = $modeById["editor_live"]
Assert-Bool -Actual (Get-RequiredBool -Object $editorLiveMode -Name "requires_editor_bridge" -Context "mode editor_live") -Expected $true -Message "editor_live must require an editor bridge."
Assert-Bool -Actual (Get-RequiredBool -Object $editorLiveMode -Name "requires_explicit_upgrade" -Context "mode editor_live") -Expected $true -Message "editor_live must require explicit upgrade."
Assert-Bool -Actual (Get-RequiredBool -Object $editorLiveMode -Name "provides_live_editor_state" -Context "mode editor_live") -Expected $true -Message "editor_live must provide live editor state."
Assert-Bool -Actual (Get-RequiredBool -Object $editorLiveMode -Name "default_enabled" -Context "mode editor_live") -Expected $false -Message "editor_live must not be enabled by default."

$capabilities = @($manifest.capabilities)
if ($capabilities.Count -eq 0) {
    throw "manifest must declare at least one capability."
}

$requiredCapabilitiesByMode = [ordered]@{
    "static_project_analysis" = "static_headless"
    "dotnet_workspace_analysis" = "static_headless"
    "resource_graph_analysis" = "static_headless"
    "editor_selection" = "editor_live"
    "inspector_state" = "editor_live"
    "dock_state" = "editor_live"
    "editor_screenshot" = "editor_live"
    "runtime_validation" = "editor_live"
}
$capabilityIds = @{}
$liveCapabilityNamePattern = "(^editor_|inspector|dock|screenshot|runtime_validation|runtime-validation)"

foreach ($capability in $capabilities) {
    $capabilityId = Get-RequiredString -Object $capability -Name "id" -Context "capability"
    if ($capabilityIds.ContainsKey($capabilityId)) {
        throw "Duplicate capability id '$capabilityId'."
    }

    $capabilityIds[$capabilityId] = $true
    $modeId = Get-RequiredString -Object $capability -Name "mode" -Context "capability '$capabilityId'"
    if (-not $requiredCapabilitiesByMode.Contains($capabilityId)) {
        throw "Unknown capability id '$capabilityId'. Add an explicit validator policy before declaring a new v2 capability."
    }

    if ($modeId -ne $requiredCapabilitiesByMode[$capabilityId]) {
        throw "Capability '$capabilityId' must use mode '$($requiredCapabilitiesByMode[$capabilityId])'."
    }

    if (-not $modeById.ContainsKey($modeId)) {
        throw "Capability '$capabilityId' references unknown mode '$modeId'."
    }

    Assert-Bool -Actual (Get-RequiredBool -Object $capability -Name "requires_project_id" -Context "capability '$capabilityId'") -Expected $true -Message "Capability '$capabilityId' must require project_id."
    Assert-Bool -Actual (Get-RequiredBool -Object $capability -Name "requires_session_id" -Context "capability '$capabilityId'") -Expected $true -Message "Capability '$capabilityId' must require session_id."
    Assert-Bool -Actual (Get-RequiredBool -Object $capability -Name "may_start_process" -Context "capability '$capabilityId'") -Expected $false -Message "Capability '$capabilityId' must not start processes by itself."
    Assert-Bool -Actual (Get-RequiredBool -Object $capability -Name "may_listen_port" -Context "capability '$capabilityId'") -Expected $false -Message "Capability '$capabilityId' must not open listening ports by itself."

    $requiresEditorBridge = Get-RequiredBool -Object $capability -Name "requires_editor_bridge" -Context "capability '$capabilityId'"
    $requiresExplicitUpgrade = Get-RequiredBool -Object $capability -Name "requires_explicit_upgrade" -Context "capability '$capabilityId'"
    $providesLiveEditorState = Get-RequiredBool -Object $capability -Name "provides_live_editor_state" -Context "capability '$capabilityId'"

    if ($modeId -eq "static_headless") {
        Assert-Bool -Actual $requiresEditorBridge -Expected $false -Message "Static/headless capability '$capabilityId' must not require the editor bridge."
        Assert-Bool -Actual $requiresExplicitUpgrade -Expected $false -Message "Static/headless capability '$capabilityId' must not require editor-live upgrade."
        Assert-Bool -Actual $providesLiveEditorState -Expected $false -Message "Static/headless capability '$capabilityId' must not provide live editor state."
        if ($capabilityId -match $liveCapabilityNamePattern) {
            throw "Static/headless capability '$capabilityId' looks like an editor-live capability."
        }
    }
    elseif ($modeId -eq "editor_live") {
        Assert-Bool -Actual $requiresEditorBridge -Expected $true -Message "Editor-live capability '$capabilityId' must require the editor bridge."
        Assert-Bool -Actual $requiresExplicitUpgrade -Expected $true -Message "Editor-live capability '$capabilityId' must require explicit upgrade."
        Assert-Bool -Actual $providesLiveEditorState -Expected $true -Message "Editor-live capability '$capabilityId' must provide live editor state."
    }
}

foreach ($requiredCapabilityId in $requiredCapabilitiesByMode.Keys) {
    if (-not $capabilityIds.ContainsKey($requiredCapabilityId)) {
        throw "manifest must declare runtime capability '$requiredCapabilityId'."
    }
}

Write-Host "v2 capability manifest validation passed: $resolvedManifestPath"
