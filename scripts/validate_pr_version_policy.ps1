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

$bridgeMetadataPaths = @(
    "addons/godot_dotnet_mcp/.dotnet_bridge/DotnetBridge.csproj",
    "addons/godot_dotnet_mcp/dotnet_bridge/DotnetBridge.csproj"
)

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
        Paths = $bridgeMetadataPaths
        Name = "bridge Version"
        Pattern = '<Version>([^<]+)</Version>'
    },
    @{
        Paths = $bridgeMetadataPaths
        Name = "bridge VersionPrefix"
        Pattern = '<VersionPrefix>([^<]+)</VersionPrefix>'
    },
    @{
        Paths = $bridgeMetadataPaths
        Name = "bridge AssemblyVersion"
        Pattern = '<AssemblyVersion>([^<]+)</AssemblyVersion>'
    },
    @{
        Paths = $bridgeMetadataPaths
        Name = "bridge FileVersion"
        Pattern = '<FileVersion>([^<]+)</FileVersion>'
    },
    @{
        Paths = $bridgeMetadataPaths
        Name = "bridge InformationalVersion"
        Pattern = '<InformationalVersion>([^<]+)</InformationalVersion>'
    }
)

function ConvertFrom-ProtocolFactsJson {
    param(
        [string]$Content,
        [string]$Source
    )

    try {
        return $Content | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "Cannot parse protocol facts JSON in $Source. $($_.Exception.Message)"
    }
}

function ConvertFrom-ProtocolFallbackFacts {
    param(
        [string]$Content,
        [string]$Source
    )

    $functionIndex = $Content.IndexOf("static func _default_facts() -> Dictionary:")
    if ($functionIndex -lt 0) {
        throw "Cannot find protocol fallback _default_facts dictionary in $Source."
    }

    $returnIndex = $Content.IndexOf("return", $functionIndex)
    $braceStart = $Content.IndexOf("{", $returnIndex)
    if ($returnIndex -lt 0 -or $braceStart -lt 0) {
        throw "Cannot find protocol fallback _default_facts return dictionary in $Source."
    }

    $braceEnd = Find-MatchingBrace -Content $Content -BraceStart $braceStart
    if ($braceEnd -lt 0) {
        throw "Cannot parse protocol fallback _default_facts dictionary braces in $Source."
    }

    $body = $Content.Substring($braceStart, $braceEnd - $braceStart + 1)
    try {
        return $body | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "Cannot parse protocol fallback _default_facts dictionary in $Source. Keep the fallback dictionary JSON-compatible. $($_.Exception.Message)"
    }
}

function Find-MatchingBrace {
    param(
        [string]$Content,
        [int]$BraceStart
    )

    $depth = 0
    $inString = $false
    $escaped = $false
    for ($index = $BraceStart; $index -lt $Content.Length; $index++) {
        $character = $Content[$index]
        if ($inString) {
            if ($escaped) {
                $escaped = $false
            } elseif ($character -eq '\') {
                $escaped = $true
            } elseif ($character -eq '"') {
                $inString = $false
            }
            continue
        }

        if ($character -eq '"') {
            $inString = $true
        } elseif ($character -eq '{') {
            $depth++
        } elseif ($character -eq '}') {
            $depth--
            if ($depth -eq 0) {
                return $index
            }
        }
    }

    return -1
}

function Get-ObjectPropertyNames {
    param([object]$Value)

    if ($null -eq $Value) {
        return @()
    }

    return @($Value.PSObject.Properties | ForEach-Object { [string]$_.Name } | Sort-Object)
}

function Assert-ProtocolFactsParity {
    param(
        [string]$Ref,
        [string]$Label
    )

    $jsonPath = "addons/godot_dotnet_mcp/plugin/runtime/mcp_protocol_facts.json"
    $fallbackPath = "addons/godot_dotnet_mcp/plugin/runtime/mcp_protocol_facts.gd"
    $jsonSource = if ([string]::IsNullOrWhiteSpace($Ref)) { $jsonPath } else { "${Ref}:$jsonPath" }
    $fallbackSource = if ([string]::IsNullOrWhiteSpace($Ref)) { $fallbackPath } else { "${Ref}:$fallbackPath" }
    $jsonFacts = ConvertFrom-ProtocolFactsJson -Content (Read-VersionContent -Ref $Ref -Path $jsonPath -Label $Label) -Source $jsonSource
    $fallbackFacts = ConvertFrom-ProtocolFallbackFacts -Content (Read-VersionContent -Ref $Ref -Path $fallbackPath -Label $Label) -Source $fallbackSource

    foreach ($field in @("protocol_version", "tool_schema_version", "server_name", "server_description", "server_version")) {
        if ([string]$jsonFacts.$field -ne [string]$fallbackFacts.$field) {
            throw "Protocol facts parity failed for $Label ${field}: $jsonSource='$($jsonFacts.$field)' but $fallbackSource='$($fallbackFacts.$field)'."
        }
    }

    $jsonErrorCodeKeys = Get-ObjectPropertyNames -Value $jsonFacts.error_codes
    $fallbackErrorCodeKeys = Get-ObjectPropertyNames -Value $fallbackFacts.error_codes
    $missingFallbackKeys = @($jsonErrorCodeKeys | Where-Object { $fallbackErrorCodeKeys -notcontains $_ })
    if ($missingFallbackKeys.Count -gt 0) {
        throw "Protocol facts parity failed for $Label error_codes: fallback is missing key(s): $($missingFallbackKeys -join ', ')."
    }

    $staleFallbackKeys = @($fallbackErrorCodeKeys | Where-Object { $jsonErrorCodeKeys -notcontains $_ })
    if ($staleFallbackKeys.Count -gt 0) {
        throw "Protocol facts parity failed for $Label error_codes: fallback has stale key(s): $($staleFallbackKeys -join ', ')."
    }

    foreach ($key in $jsonErrorCodeKeys) {
        if ([string]$jsonFacts.error_codes.$key -ne [string]$fallbackFacts.error_codes.$key) {
            throw "Protocol facts parity failed for $Label error_codes.${key}: JSON='$($jsonFacts.error_codes.$key)' but fallback='$($fallbackFacts.error_codes.$key)'."
        }
    }
}

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

function Test-VersionMetadataPathExists {
    param(
        [string]$Ref,
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Ref)) {
        return Test-Path -LiteralPath (Join-Path $RepositoryRoot $Path)
    }

    $output = Invoke-Git -Arguments @("ls-tree", "--name-only", $Ref, "--", $Path)
    $entries = @($output -split "\r?\n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    return $entries -contains $Path
}

function Read-VersionFieldCandidates {
    param(
        [hashtable]$Field,
        [string]$Ref,
        [string]$Label
    )

    $paths = @()
    if ($Field.ContainsKey("Paths")) {
        $paths = @($Field.Paths)
    } else {
        $paths = @($Field.Path)
    }

    $candidates = New-Object System.Collections.Generic.List[object]
    foreach ($path in $paths) {
        if (Test-VersionMetadataPathExists -Ref $Ref -Path $path) {
            $source = if ([string]::IsNullOrWhiteSpace($Ref)) { $path } else { "${Ref}:$path" }
            $candidates.Add([pscustomobject]@{
                Content = Read-VersionContent -Ref $Ref -Path $path -Label $Label
                Path = $path
                Source = $source
            })
        }
    }

    if ($candidates.Count -gt 0) {
        return $candidates.ToArray()
    }

    throw "Cannot find $Label metadata file for $($Field.Name): $($paths -join ', ')"
}

function Test-IsV2StackBaseBranch {
    param([string]$Branch)

    if ([string]::IsNullOrWhiteSpace($Branch)) {
        return $false
    }

    if ($Branch -eq "release/v2.0.0-baseline") {
        return $true
    }

    foreach ($prefix in @("feature/v2-", "docs/v2-", "ci/v2-")) {
        if ($Branch.StartsWith($prefix, [System.StringComparison]::Ordinal)) {
            return $true
        }
    }

    return $false
}

function Test-IsAllowedBaseBranch {
    param([string]$Branch)

    return $Branch -in @("dev", "refactor/v1.4.0", "refactor/v2.0.0", "v2.0") -or (Test-IsV2StackBaseBranch -Branch $Branch)
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

function Get-VersionFieldValue {
    param(
        [hashtable]$Field,
        [string]$Ref,
        [string]$Label
    )

    $candidates = @(Read-VersionFieldCandidates -Field $Field -Ref $Ref -Label $Label)
    $values = New-Object System.Collections.Generic.List[object]
    foreach ($candidate in $candidates) {
        $values.Add([pscustomobject]@{
            Value = Get-VersionValue -Content $candidate.Content -Pattern $Field.Pattern -Source $candidate.Source -Name $Field.Name
            Path = $candidate.Path
            Source = $candidate.Source
        })
    }

    $first = $values[0]
    $drifted = @($values | Where-Object { $_.Value -ne $first.Value })
    if ($drifted.Count -gt 0) {
        $summary = @($values | ForEach-Object { "$($_.Source)='$($_.Value)'" }) -join "; "
        throw "$Label $($Field.Name) metadata candidates disagree: $summary"
    }

    return $first
}

$hasExplicitContext = -not [string]::IsNullOrWhiteSpace($BaseBranch) -or -not [string]::IsNullOrWhiteSpace($HeadBranch) -or -not [string]::IsNullOrWhiteSpace($BaseRef) -or -not [string]::IsNullOrWhiteSpace($HeadRef) -or $PullNumber -gt 0
if (-not $hasExplicitContext) {
    Write-Host "Version policy validation skipped: no pull request context was provided."
    exit 0
}

if ([string]::IsNullOrWhiteSpace($BaseBranch)) {
    throw "Version policy validation requires a base branch. Set GITHUB_BASE_REF or pass -BaseBranch."
}

if (-not (Test-IsAllowedBaseBranch -Branch $BaseBranch)) {
    throw "Version policy validation expects pull requests to target dev, refactor/v1.4.0, refactor/v2.0.0, v2.0, or a v2 stacked base branch. Actual base branch: $BaseBranch"
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

Assert-ProtocolFactsParity -Ref $HeadRef -Label "head"

$changes = New-Object System.Collections.Generic.List[string]
foreach ($field in $versionFields) {
    $baseMetadata = Get-VersionFieldValue -Field $field -Ref $BaseRef -Label "base"
    $headMetadata = Get-VersionFieldValue -Field $field -Ref $HeadRef -Label "head"
    $baseValue = $baseMetadata.Value
    $headValue = $headMetadata.Value

    if ($baseValue -ne $headValue) {
        $changes.Add("$($field.Name): $baseValue -> $headValue")
    }
}

if ($changes.Count -eq 0) {
    Write-Host "Version policy validated: public version metadata remains unchanged."
    exit 0
}

if ($BaseBranch -eq "refactor/v1.4.0" -and $HeadBranch -eq "refactor/v2.0.0") {
    if ($RequireTrustedReleaseBranch -and ([string]::IsNullOrWhiteSpace($RepositoryOwner) -or [string]::IsNullOrWhiteSpace($HeadRepositoryOwner) -or $RepositoryOwner -ne $HeadRepositoryOwner)) {
        throw "v2.0 refactor migration version changes must come from the base repository. Head owner: $HeadRepositoryOwner; repository owner: $RepositoryOwner."
    }

    Write-Host "Version policy validated: v2.0 refactor migration branch changes public version metadata:"
    foreach ($change in $changes) {
        Write-Host "- $change"
    }
    exit 0
}

if ($BaseBranch -eq "refactor/v2.0.0" -and $HeadBranch -eq "chore/v2.0-version-baseline") {
    if ($RequireTrustedReleaseBranch -and ([string]::IsNullOrWhiteSpace($RepositoryOwner) -or [string]::IsNullOrWhiteSpace($HeadRepositoryOwner) -or $RepositoryOwner -ne $HeadRepositoryOwner)) {
        throw "v2.0 refactor baseline version changes must come from the base repository. Head owner: $HeadRepositoryOwner; repository owner: $RepositoryOwner."
    }

    Write-Host "Version policy validated: v2.0 refactor baseline branch changes public version metadata:"
    foreach ($change in $changes) {
        Write-Host "- $change"
    }
    exit 0
}

if ($BaseBranch -eq "dev" -and $HeadBranch -eq "refactor/v2.0.0") {
    if ($RequireTrustedReleaseBranch -and ([string]::IsNullOrWhiteSpace($RepositoryOwner) -or [string]::IsNullOrWhiteSpace($HeadRepositoryOwner) -or $RepositoryOwner -ne $HeadRepositoryOwner)) {
        throw "v2.0 refactor integration version changes must come from the base repository. Head owner: $HeadRepositoryOwner; repository owner: $RepositoryOwner."
    }

    Write-Host "Version policy validated: v2.0 refactor integration branch changes public version metadata:"
    foreach ($change in $changes) {
        Write-Host "- $change"
    }
    exit 0
}

if ($HeadBranch -like "release/*") {
    if ($BaseBranch -notin @("dev", "v2.0")) {
        throw "Release version changes must target dev or v2.0. Actual base branch: $BaseBranch"
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
throw "Move final plugin version changes to a release/* branch targeting dev or v2.0."
