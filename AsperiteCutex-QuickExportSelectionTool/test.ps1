# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Interaksiyon

[CmdletBinding()]
param(
    [string]$AsepritePath = '',
    [switch]$KeepArtifacts
)

$ErrorActionPreference = 'Stop'
if (-not $AsepritePath) {
    $command = Get-Command aseprite -ErrorAction SilentlyContinue
    if ($command) {
        $AsepritePath = $command.Source
    }
    else {
        $candidates = @(
            'C:\Program Files\Aseprite\Aseprite.exe',
            'C:\Program Files (x86)\Aseprite\Aseprite.exe',
            'C:\Program Files (x86)\Steam\steamapps\common\Aseprite\Aseprite.exe',
            'C:\Program Files\Steam\steamapps\common\Aseprite\Aseprite.exe'
        )
        $AsepritePath = $candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
    }
}
if (-not $AsepritePath -or -not (Test-Path -LiteralPath $AsepritePath -PathType Leaf)) {
    throw 'Aseprite not found. Pass -AsepritePath with the path to Aseprite.exe.'
}

$projectRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$testScript = Join-Path $projectRoot 'tests/integration.lua'
$runId = [Guid]::NewGuid().ToString('N')
$outputRoot = Join-Path $projectRoot 'tests/output'
$configRoot = Join-Path $projectRoot 'tests/config'
$outputPath = Join-Path $outputRoot $runId
$configPath = Join-Path $configRoot $runId
$null = New-Item -ItemType Directory -Path $outputPath, $configPath -Force
$reportPath = Join-Path $outputPath 'report.txt'
$runSucceeded = $false
$process = $null

function Remove-TestRun {
    param([string]$RunPath, [string]$AllowedRoot)

    $absoluteRoot = [System.IO.Path]::GetFullPath($AllowedRoot).TrimEnd('\', '/')
    $absoluteRun = [System.IO.Path]::GetFullPath($RunPath)
    $rootPrefix = $absoluteRoot + [System.IO.Path]::DirectorySeparatorChar
    if (-not $absoluteRun.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase) -or
        [System.IO.Path]::GetFileName($absoluteRun) -ne $runId) {
        throw "Refusing to remove a directory outside this test run: $absoluteRun"
    }
    foreach ($path in @($absoluteRoot, $absoluteRun)) {
        $item = Get-Item -LiteralPath $path -Force
        if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Refusing to remove a test directory through a junction or symbolic link: $path"
        }
    }
    Remove-Item -LiteralPath $absoluteRun -Recurse -Force
}

# Aseprite officially supports this environment variable for isolated tests.
# Restore its previous value when this runner exits.
$previousUserFolder = $env:ASEPRITE_USER_FOLDER
try {
    $env:ASEPRITE_USER_FOLDER = $configPath
    $arguments = @(
        '--batch',
        '--script-param', ('"project=' + $projectRoot + '"'),
        '--script-param', ('"output=' + $outputPath + '"'),
        '--script', ('"' + $testScript + '"')
    )
    $process = Start-Process -FilePath $AsepritePath -ArgumentList $arguments -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru
    if (-not $process.WaitForExit(45000)) {
        $process.Kill()
        $null = $process.WaitForExit(5000)
        throw 'Aseprite tests timed out after 45 seconds.'
    }
    $process.Refresh()
    if (-not (Test-Path -LiteralPath $reportPath -PathType Leaf)) {
        throw "Aseprite exited with code $($process.ExitCode) without a test report. Expected: $reportPath"
    }
    $report = Get-Content -LiteralPath $reportPath -Encoding UTF8
    $report | Write-Output
    if ($report[-1] -ne 'RESULT: PASS') {
        throw 'Aseprite integration tests failed. See the report above.'
    }
    if ($process.ExitCode -ne 0) {
        throw "Aseprite exited with code $($process.ExitCode)."
    }
    $runSucceeded = $true
}
finally {
    $env:ASEPRITE_USER_FOLDER = $previousUserFolder
    if ($process) { $process.Dispose() }
    if ($runSucceeded -and -not $KeepArtifacts) {
        Remove-TestRun -RunPath $outputPath -AllowedRoot $outputRoot
        Remove-TestRun -RunPath $configPath -AllowedRoot $configRoot
    }
}

if ($KeepArtifacts) {
    Write-Output "Test artifacts: $outputPath"
}
else {
    Write-Output 'Successful test run artifacts removed. Use -KeepArtifacts to retain them.'
}
