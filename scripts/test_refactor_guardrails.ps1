param()

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

function Write-Utf8NoBom {
    param(
        [string]$Path,
        [string]$Text
    )

    $directory = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding($false)))
}

function New-GuardrailFixture {
    param(
        [string]$Root,
        [switch]$MissingTrackerFact
    )

    New-Item -ItemType Directory -Path $Root -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $Root "scripts") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $Root "dist") -Force | Out-Null
    git -C $Root init --quiet
    Copy-Item -LiteralPath (Join-Path $repoRoot "scripts\validate_refactor_guardrails.ps1") -Destination (Join-Path $Root "scripts\validate_refactor_guardrails.ps1") -Force

    $planText = @'
# v1.4.0 Protocol Refactor Plan

MCP 2025-11-25
protocolVersion = 2025-11-25
http://127.0.0.1:3000/mcp
Accept: application/json, text/event-stream
MCP-Protocol-Version: 2025-11-25
Sampling, Elicitation, and Tasks as optional capabilities
do not implement or advertise them by default
legacy compatibility surfaces
'@

    $trackerText = @'
# v1.4.0 Refactor Progress Tracker

MCP 2025-11-25 conformance by default
2025-06-18 alignment retained as a compatibility foundation
http://127.0.0.1:3000/mcp
MCP Streamable HTTP
legacy `/api/tools`, `/health`, JSON-only POST behavior, and `Content-Length` stdio
A PR is not ready to merge into the v1.4 refactor branch until local validation, relevant GitHub checks, all conversations, and the Codex review gate are complete.
'@

    if ($MissingTrackerFact) {
        $trackerText = $trackerText.Replace("MCP Streamable HTTP", "HTTP endpoint")
    }

    Write-Utf8NoBom -Path (Join-Path $Root "docs\en\process\v1.4.0-protocol-refactor-plan.md") -Text $planText
    Write-Utf8NoBom -Path (Join-Path $Root "docs\en\process\v1.4.0-refactor-progress-tracker.md") -Text $trackerText
}

function Invoke-GuardrailFixture {
    param(
        [string]$Root
    )

    Push-Location $Root
    $output = @()
    try {
        $output = & (Join-Path $Root "scripts\validate_refactor_guardrails.ps1") -SkipVersionPolicy 2>&1
        return @{
            ExitCode = $LASTEXITCODE
            Output = ($output | Out-String)
            Succeeded = $true
        }
    }
    catch {
        $combinedOutput = (($output | Out-String) + [Environment]::NewLine + $_.Exception.Message).Trim()
        return @{
            ExitCode = 1
            Output = $combinedOutput
            Succeeded = $false
        }
    }
    finally {
        Pop-Location
    }
}

$fixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("godot-dotnet-mcp-refactor-guardrails-" + [Guid]::NewGuid().ToString("N"))
try {
    $validRoot = Join-Path $fixtureRoot "valid"
    New-GuardrailFixture -Root $validRoot
    $validResult = Invoke-GuardrailFixture -Root $validRoot
    if (-not $validResult.Succeeded) {
        throw "Expected valid refactor guardrail fixture to pass, got: $($validResult.Output)"
    }

    $invalidRoot = Join-Path $fixtureRoot "invalid"
    New-GuardrailFixture -Root $invalidRoot -MissingTrackerFact
    $invalidResult = Invoke-GuardrailFixture -Root $invalidRoot
	if ($invalidResult.Succeeded) {
		throw "Expected invalid refactor guardrail fixture to fail."
	}
}
finally {
    if (Test-Path -LiteralPath $fixtureRoot) {
        Remove-Item -LiteralPath $fixtureRoot -Recurse -Force
    }
}

Write-Host "Refactor guardrail tests passed."
