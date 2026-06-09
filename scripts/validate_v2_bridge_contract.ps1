param(
    [string]$SchemaPath = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($SchemaPath)) {
    $repositoryRoot = Split-Path -Parent $PSScriptRoot
    $SchemaPath = Join-Path $repositoryRoot "addons\godot_dotnet_mcp\companion\contracts\v2-bridge-status.schema.json"
}

$schema = Get-Content -LiteralPath (Resolve-Path -LiteralPath $SchemaPath) -Encoding UTF8 -Raw | ConvertFrom-Json

if ($schema.title -ne "Godot .NET MCP v2 Editor Bridge Status") {
    throw "Unexpected bridge status schema title."
}

$stateProperty = $schema.properties.state
$states = @($stateProperty.enum)
foreach ($requiredState in @("disabled", "offline", "online", "version_mismatch")) {
    if ($states -notcontains $requiredState) {
        throw "Bridge status schema must include state '$requiredState'."
    }
}

$required = @($schema.required)
foreach ($requiredProperty in @("schema_version", "state", "project_id", "editor_session_id", "plugin_version", "supports_live_editor_state")) {
    if ($required -notcontains $requiredProperty) {
        throw "Bridge status schema must require '$requiredProperty'."
    }
}

$allOf = @($schema.allOf)
$onlineRule = $allOf | Where-Object { $_.if.properties.state.const -eq "online" } | Select-Object -First 1
if ($null -eq $onlineRule) {
    throw "Bridge status schema must declare an online rule."
}

if ($onlineRule.then.properties.editor_session_id.type -ne "string") {
    throw "Online bridge status must require a string editor_session_id."
}

if ([int]$onlineRule.then.properties.editor_session_id.minLength -lt 1) {
    throw "Online bridge status must require a non-empty editor_session_id."
}

if ($onlineRule.then.properties.plugin_version.type -ne "string") {
    throw "Online bridge status must require a string plugin_version."
}

$expectedPluginVersionPattern = "^v?2\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$"
if ($schema.properties.plugin_version.pattern -ne $expectedPluginVersionPattern) {
    throw "Bridge status schema plugin_version pattern must match the v2 compatibility policy."
}

if ($onlineRule.then.properties.supports_live_editor_state.const -ne $true) {
    throw "Online bridge status must support live editor state."
}

$requiredNonLiveStates = @("disabled", "offline", "version_mismatch")
$nonLiveRule = $allOf | Where-Object {
    $ruleStates = @($_.if.properties.state.enum)
    $ruleStates.Count -eq $requiredNonLiveStates.Count -and
        -not (@($requiredNonLiveStates | Where-Object { $ruleStates -notcontains $_ }))
} | Select-Object -First 1
if ($null -eq $nonLiveRule) {
    throw "Bridge status schema must declare one non-live state rule for exactly disabled, offline, and version_mismatch."
}

if ($nonLiveRule.then.properties.supports_live_editor_state.const -ne $false) {
    throw "Disabled/offline/version_mismatch bridge states must not support live editor state."
}

if ($schema.additionalProperties -ne $false) {
    throw "Bridge status schema must reject additional properties."
}

Write-Host "v2 bridge contract validation passed: $SchemaPath"
