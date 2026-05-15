param(
    [string]$Description,
    [string]$ProjectPath,
    [string]$Configuration = "Release",
    [string[]]$AdditionalArguments = @(),
    [switch]$SelfTest
)

$ErrorActionPreference = "Stop"

function Get-DotnetBuildFailureDiagnostic {
    param(
        [string]$OutputText
    )

    if ([string]::IsNullOrWhiteSpace($OutputText)) {
        return $null
    }

    $matchedSignals = New-Object System.Collections.Generic.List[string]
    if ($OutputText -match '(?i)\bCS2012\b') {
        $matchedSignals.Add("CS2012")
    }

    if ($OutputText -match '(?i)\.godot[\\/]mono[\\/]temp') {
        $matchedSignals.Add("godot_mono_temp_path")
    }

    $lockPatterns = @(
        @{ Name = "used_by_another_process"; Pattern = '(?i)used by another process' },
        @{ Name = "process_cannot_access_file"; Pattern = '(?i)process cannot access the file' },
        @{ Name = "access_denied"; Pattern = '(?i)access\s+denied' },
        @{ Name = "zh_access_denied"; Pattern = '访问被拒绝' },
        @{ Name = "zh_another_process"; Pattern = '另一个进程|另一进程' },
        @{ Name = "microsoft_defender"; Pattern = '(?i)Microsoft Defender' },
        @{ Name = "antivirus"; Pattern = '(?i)anti[- ]?virus|防病毒' }
    )

    foreach ($entry in $lockPatterns) {
        if ($OutputText -match $entry.Pattern) {
            $matchedSignals.Add($entry.Name)
        }
    }

    $hasCompilerCode = $matchedSignals.Contains("CS2012")
    $hasGodotTempPath = $matchedSignals.Contains("godot_mono_temp_path")
    $hasLockSignal = $matchedSignals.Count -gt 2
    if (-not ($hasCompilerCode -and $hasGodotTempPath -and $hasLockSignal)) {
        return $null
    }

    $path = $null
    $quotedPathMatch = [regex]::Match($OutputText, '(?i)[''"](?<path>[^''"]*\.godot[\\/]mono[\\/]temp[^''"]*)[''"]')
    if ($quotedPathMatch.Success) {
        $path = $quotedPathMatch.Groups["path"].Value
    }
    else {
        $pathMatch = [regex]::Match($OutputText, '(?i)(?<path>\S*\.godot[\\/]mono[\\/]temp\S*)')
        if ($pathMatch.Success) {
            $path = $pathMatch.Groups["path"].Value.Trim()
        }
    }

    $processName = $null
    if ($OutputText -match '(?i)Microsoft Defender') {
        $processName = "Microsoft Defender"
    }
    elseif ($OutputText -match '(?i)anti[- ]?virus|防病毒') {
        $processName = "security software"
    }

    return [pscustomobject]@{
        kind = "transient_file_lock"
        code = "CS2012"
        path = $path
        matched_signals = @($matchedSignals.ToArray())
        process_name = $processName
        recommendations = @(
            "Wait briefly, then rerun the same dotnet build command.",
            "If this repeats, consider excluding the Godot .godot/mono/temp build directory from security software scanning.",
            "Do not automatically delete .godot or terminate editor/security processes for this diagnostic."
        )
    }
}

function Format-DotnetBuildFailureDiagnostic {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Diagnostic
    )

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("")
    $lines.Add("dotnet_build_failure_diagnostic:")
    $lines.Add("  kind: $($Diagnostic.kind)")
    $lines.Add("  code: $($Diagnostic.code)")
    if (-not [string]::IsNullOrWhiteSpace($Diagnostic.path)) {
        $lines.Add("  path: $($Diagnostic.path)")
    }
    $lines.Add("  matched_signals: $(@($Diagnostic.matched_signals) -join ', ')")
    if (-not [string]::IsNullOrWhiteSpace($Diagnostic.process_name)) {
        $lines.Add("  process_name: $($Diagnostic.process_name)")
    }
    $lines.Add("  recommendations:")
    foreach ($recommendation in $Diagnostic.recommendations) {
        $lines.Add("    - $recommendation")
    }

    return $lines.ToArray()
}

function Invoke-DotnetBuildWithDiagnostics {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Description,
        [Parameter(Mandatory = $true)]
        [string]$ProjectPath,
        [string]$Configuration = "Release",
        [string[]]$AdditionalArguments = @()
    )

    $arguments = @("build", $ProjectPath, "-c", $Configuration) + $AdditionalArguments
    $outputLines = & dotnet @arguments 2>&1 | ForEach-Object {
        $line = $_.ToString()
        Write-Host $line
        $line
    }
    $exitCode = $LASTEXITCODE
    $outputText = ($outputLines -join [Environment]::NewLine).Trim()

    if ($exitCode -ne 0) {
        $diagnostic = Get-DotnetBuildFailureDiagnostic -OutputText $outputText
        if ($diagnostic -ne $null) {
            Format-DotnetBuildFailureDiagnostic -Diagnostic $diagnostic | ForEach-Object { Write-Host $_ }
        }

        $details = if ([string]::IsNullOrWhiteSpace($outputText)) { "<no output>" } else { $outputText }
        throw "$Description failed with exit code $exitCode.`n$details"
    }


}

function Assert-DiagnosticCondition {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Invoke-DotnetBuildFailureDiagnosticsSelfTest {
    $positiveOutput = "CSC : error CS2012: Cannot open 'C:\repo\.godot\mono\temp\obj\Debug\Fixture.dll' for writing -- The process cannot access the file because it is being used by another process. Microsoft Defender Antivirus"
    $diagnostic = Get-DotnetBuildFailureDiagnostic -OutputText $positiveOutput
    Assert-DiagnosticCondition -Condition ($diagnostic -ne $null) -Message "Expected transient_file_lock diagnostic for CS2012 Godot temp lock output."
    Assert-DiagnosticCondition -Condition ($diagnostic.kind -eq "transient_file_lock") -Message "Expected diagnostic kind transient_file_lock."
    Assert-DiagnosticCondition -Condition ($diagnostic.path -like "*.godot\mono\temp*") -Message "Expected diagnostic path to include .godot\mono\temp."

    $nonGodotCs2012 = "CSC : error CS2012: Cannot open 'C:\repo\bin\Debug\Fixture.dll' for writing -- The process cannot access the file because it is being used by another process."
    Assert-DiagnosticCondition -Condition ((Get-DotnetBuildFailureDiagnostic -OutputText $nonGodotCs2012) -eq $null) -Message "CS2012 outside Godot temp must not be classified."

    $noCompilerCode = "Cannot open 'C:\repo\.godot\mono\temp\obj\Debug\Fixture.dll' because it is being used by another process."
    Assert-DiagnosticCondition -Condition ((Get-DotnetBuildFailureDiagnostic -OutputText $noCompilerCode) -eq $null) -Message "Godot temp lock without CS2012 must not be classified."

    $ordinaryCompileError = "Program.cs(1,1): error CS1002: ; expected"
    Assert-DiagnosticCondition -Condition ((Get-DotnetBuildFailureDiagnostic -OutputText $ordinaryCompileError) -eq $null) -Message "Ordinary compiler errors must not be classified."

    Write-Host "dotnet build failure diagnostics self-test passed."
}

if ($MyInvocation.InvocationName -ne ".") {
    try {
        if ($SelfTest) {
            Invoke-DotnetBuildFailureDiagnosticsSelfTest
            exit 0
        }

        if ([string]::IsNullOrWhiteSpace($Description) -or [string]::IsNullOrWhiteSpace($ProjectPath)) {
            throw "Pass -Description and -ProjectPath, or use -SelfTest."
        }

        Invoke-DotnetBuildWithDiagnostics -Description $Description -ProjectPath $ProjectPath -Configuration $Configuration -AdditionalArguments $AdditionalArguments | Out-Null
        exit 0
    }
    catch {
        Write-Error $_
        exit 1
    }
}

