param()

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$workflowPath = Join-Path $repoRoot ".github\workflows\publish-plugin.yml"

if (-not (Test-Path -LiteralPath $workflowPath)) {
    throw "publish-plugin workflow was not found: $workflowPath"
}

$workflowText = Get-Content -LiteralPath $workflowPath -Raw -Encoding UTF8

$requiredText = @(
    "workflow_dispatch:",
    "Require release tag ref",
    'RELEASE_REF: ${{ github.ref }}',
    'StartsWith("refs/tags/")',
    "publish-plugin validates release tags only",
    "Run release preflight",
    "Render release notes",
    "Upload release notes"
)

foreach ($needle in $requiredText) {
    if (-not $workflowText.Contains($needle)) {
        throw "publish-plugin workflow policy is missing required text: $needle"
    }
}

$tagOnlyConditionalPattern = "(?m)^\s*if:\s*startsWith\(github\.ref,\s*'refs/tags/'\)"
if ($workflowText -match $tagOnlyConditionalPattern) {
    throw "publish-plugin must not silently skip release preflight or release-note validation on non-tag refs; use the explicit Require release tag ref step instead."
}

Write-Host "publish-plugin workflow policy validated successfully."
