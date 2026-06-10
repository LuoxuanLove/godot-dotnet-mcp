param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$BaseBranch = $env:GITHUB_BASE_REF,
    [string]$HeadBranch = $env:GITHUB_HEAD_REF,
    [string]$BaseRef = "",
    [string]$HeadRef = "",
    [int]$PullNumber = 0,
    [string]$RepositoryOwner = "",
    [string]$HeadRepositoryOwner = "",
    [switch]$RequireTrustedReleaseBranch,
    [switch]$SkipFetch
)

$ErrorActionPreference = "Stop"

$versionFields = @(
    @{
        Path = "addons/godot_dotnet_mcp/plugin.cfg"
        Name = "plugin.cfg version"
        Pattern = 'version\s*=\s*"([^"]+)"'
    },
    @{
        Path = "addons/godot_dotnet_mcp/plugin/runtime/mcp_protocol_facts.json"
        Name = "protocol facts server_version"
        Pattern = '"server_version"\s*:\s*"([^"]+)"'
    },
    @{
        Path = "addons/godot_dotnet_mcp/plugin/runtime/mcp_protocol_facts.gd"
        Name = "protocol fallback server_version"
        Pattern = '"server_version"\s*:\s*"([^"]+)"'
    },
    @{
        Path = "addons/godot_dotnet_mcp/dotnet_bridge/DotnetBridge.csproj"
        Name = "bridge Version"
        Pattern = '<Version>([^<]+)</Version>'
    },
    @{
        Path = "addons/godot_dotnet_mcp/dotnet_bridge/DotnetBridge.csproj"
        Name = "bridge VersionPrefix"
        Pattern = '<VersionPrefix>([^<]+)</VersionPrefix>'
    },
    @{
        Path = "addons/godot_dotnet_mcp/dotnet_bridge/DotnetBridge.csproj"
        Name = "bridge AssemblyVersion"
        Pattern = '<AssemblyVersion>([^<]+)</AssemblyVersion>'
    },
    @{
        Path = "addons/godot_dotnet_mcp/dotnet_bridge/DotnetBridge.csproj"
        Name = "bridge FileVersion"
        Pattern = '<FileVersion>([^<]+)</FileVersion>'
    },
    @{
        Path = "addons/godot_dotnet_mcp/dotnet_bridge/DotnetBridge.csproj"
        Name = "bridge InformationalVersion"
        Pattern = '<InformationalVersion>([^<]+)</InformationalVersion>'
    }
)

function Invoke-Git {
    param([string[]]$Arguments)

    $output = & git -C $RepositoryRoot @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        $message = ($output | Out-String).Trim()
        throw "git $($Arguments -join ' ') failed. $message"
    }

    return ($output | Out-String)
}

function Read-VersionContent {
    param(
        [string]$Ref,
        [string]$Path,
        [string]$Label
    )

    if ([string]::IsNullOrWhiteSpace($Ref)) {
        $absolutePath = Join-Path $RepositoryRoot $Path
        if (-not (Test-Path -LiteralPath $absolutePath)) {
            throw "Cannot find $Label metadata file: $Path"
        }
        return Get-Content -LiteralPath $absolutePath -Raw -Encoding UTF8
    }

    return Invoke-Git -Arguments @("show", "${Ref}:$Path")
}

function Get-VersionValue {
    param(
        [string]$Content,
        [string]$Pattern,
        [string]$Source,
        [string]$Name
    )

    if ($Content -notmatch $Pattern) {
        throw "Cannot find $Name in $Source."
    }

    return $Matches[1]
}

$hasExplicitContext = -not [string]::IsNullOrWhiteSpace($BaseBranch) -or -not [string]::IsNullOrWhiteSpace($HeadBranch) -or -not [string]::IsNullOrWhiteSpace($BaseRef) -or -not [string]::IsNullOrWhiteSpace($HeadRef) -or $PullNumber -gt 0
if (-not $hasExplicitContext) {
    Write-Host "Version policy validation skipped: no pull request context was provided."
    exit 0
}

if ([string]::IsNullOrWhiteSpace($BaseBranch)) {
    throw "Version policy validation requires a base branch. Set GITHUB_BASE_REF or pass -BaseBranch."
}

$allowedBaseBranches = @("dev", "refactor/v1.4.0")
if ($allowedBaseBranches -notcontains $BaseBranch) {
    throw "Version policy validation expects pull requests to target dev or refactor/v1.4.0. Actual base branch: $BaseBranch"
}

if ([string]::IsNullOrWhiteSpace($HeadBranch)) {
    throw "Version policy validation requires a head branch. Set GITHUB_HEAD_REF or pass -HeadBranch."
}

if ([string]::IsNullOrWhiteSpace($BaseRef)) {
    $BaseRef = "origin/$BaseBranch"
}

if (-not $SkipFetch) {
    if ($BaseRef -eq "origin/$BaseBranch") {
        Invoke-Git -Arguments @("fetch", "--no-tags", "--depth=1", "origin", "+refs/heads/$($BaseBranch):refs/remotes/origin/$($BaseBranch)") | Out-Null
    }
    if ([string]::IsNullOrWhiteSpace($HeadRef) -and $PullNumber -gt 0) {
        $HeadRef = "refs/remotes/pull/$PullNumber/head"
        Invoke-Git -Arguments @("fetch", "--no-tags", "--depth=1", "origin", "+refs/pull/$PullNumber/head:$HeadRef") | Out-Null
    }
}

$changes = New-Object System.Collections.Generic.List[string]
foreach ($field in $versionFields) {
    $baseSource = "${BaseRef}:$($field.Path)"
    $headSource = if ([string]::IsNullOrWhiteSpace($HeadRef)) { $field.Path } else { "${HeadRef}:$($field.Path)" }
    $baseContent = Read-VersionContent -Ref $BaseRef -Path $field.Path -Label "base"
    $headContent = Read-VersionContent -Ref $HeadRef -Path $field.Path -Label "head"
    $baseValue = Get-VersionValue -Content $baseContent -Pattern $field.Pattern -Source $baseSource -Name $field.Name
    $headValue = Get-VersionValue -Content $headContent -Pattern $field.Pattern -Source $headSource -Name $field.Name

    if ($baseValue -ne $headValue) {
        $changes.Add("$($field.Name): $baseValue -> $headValue")
    }
}

if ($changes.Count -eq 0) {
    Write-Host "Version policy validated: public version metadata remains unchanged."
    exit 0
}

if ($HeadBranch -like "release/*") {
    if ($BaseBranch -ne "dev") {
        throw "Release version changes must target dev. Actual base branch: $BaseBranch"
    }

    if ($RequireTrustedReleaseBranch -and ([string]::IsNullOrWhiteSpace($RepositoryOwner) -or [string]::IsNullOrWhiteSpace($HeadRepositoryOwner) -or $RepositoryOwner -ne $HeadRepositoryOwner)) {
        throw "Release version changes must come from a release/* branch in the base repository. Head owner: $HeadRepositoryOwner; repository owner: $RepositoryOwner."
    }

    Write-Host "Version policy validated: release branch $HeadBranch changes public version metadata:"
    foreach ($change in $changes) {
        Write-Host "- $change"
    }
    exit 0
}

foreach ($change in $changes) {
    Write-Error "Non-release branch '$HeadBranch' changes public version metadata: $change"
}
throw "Move final plugin version changes to a release/* branch targeting dev."
