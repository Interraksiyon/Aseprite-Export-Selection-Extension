# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Interaksiyon

[CmdletBinding()]
param(
    [switch]$Packages
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$projectRoot = Split-Path -Parent $PSScriptRoot
$sourcePaths = @(& (Join-Path $PSScriptRoot 'source-files.ps1'))
$utf8 = [System.Text.UTF8Encoding]::new($false, $true)

foreach ($relativePath in $sourcePaths) {
    $fullPath = Join-Path $projectRoot $relativePath
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        throw "Required source file is missing: $relativePath"
    }
    $text = [System.IO.File]::ReadAllText($fullPath, $utf8)
    $bytes = [System.IO.File]::ReadAllBytes($fullPath)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191) {
        throw "Use UTF-8 without a BOM: $relativePath"
    }
    if (-not $text.EndsWith("`n")) {
        throw "Missing final newline: $relativePath"
    }
    if ($text.Contains("`r") -or $text -match '(?m)[\t ]+$') {
        throw "Use LF line endings and remove trailing whitespace: $relativePath"
    }
    if ($relativePath.EndsWith('.ps1')) {
        $tokens = $null
        $parseErrors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile($fullPath, [ref]$tokens, [ref]$parseErrors)
        if ($parseErrors.Count -gt 0) {
            throw "PowerShell syntax errors in ${relativePath}: $($parseErrors.Message -join '; ')"
        }
    }
}

$manifest = [System.IO.File]::ReadAllText((Join-Path $projectRoot 'package.json'), $utf8) | ConvertFrom-Json
if ($manifest.name -notmatch '^[a-z0-9]+(?:-[a-z0-9]+)*$' -or $manifest.version -notmatch '^\d+\.\d+\.\d+$') {
    throw 'The extension name or semantic version is invalid.'
}
if ($manifest.author.name -ne 'Interaksiyon' -or $manifest.license -ne 'MIT') {
    throw 'Author and license must identify Interaksiyon and MIT.'
}
if (@($manifest.contributes.scripts).Count -ne 1 -or $manifest.contributes.scripts[0].path -ne './main.lua') {
    throw 'The extension must contribute ./main.lua.'
}
$license = [System.IO.File]::ReadAllText((Join-Path $projectRoot 'LICENSE'), $utf8)
if (-not $license.StartsWith("MIT License`n") -or -not $license.Contains('Copyright (c) 2026 Interaksiyon')) {
    throw 'LICENSE is missing the MIT title or Interaksiyon copyright notice.'
}

foreach ($relativePath in ($sourcePaths | Where-Object { $_.EndsWith('.md') })) {
    $text = [System.IO.File]::ReadAllText((Join-Path $projectRoot $relativePath), $utf8)
    foreach ($match in [regex]::Matches($text, '\]\(([^)\s]+)\)')) {
        $target = $match.Groups[1].Value
        if ($target -match '^(https?://|mailto:|#)') { continue }
        $target = [Uri]::UnescapeDataString(($target -split '#', 2)[0])
        $documentFolder = Split-Path -Parent (Join-Path $projectRoot $relativePath)
        if (-not (Test-Path -LiteralPath (Join-Path $documentFolder $target))) {
            throw "Broken local link in ${relativePath}: $target"
        }
    }
}

Write-Output "Repository checks passed ($($sourcePaths.Count) source files; v$($manifest.version), MIT, Interaksiyon)."

if (-not $Packages) { return }

Add-Type -AssemblyName System.IO.Compression.FileSystem
$distPath = Join-Path $projectRoot 'dist'
$baseName = "$($manifest.name)-$($manifest.version)"
$archives = @(
    @{ Name = "$baseName.aseprite-extension"; Entries = @('LICENSE', 'main.lua', 'package.json') }
    @{ Name = "$baseName-source.zip"; Entries = $sourcePaths }
)
foreach ($package in $archives) {
    $archivePath = Join-Path $distPath $package.Name
    $archive = [System.IO.Compression.ZipFile]::OpenRead($archivePath)
    try {
        $expected = @($package.Entries | Sort-Object)
        $actual = @($archive.Entries | ForEach-Object { $_.FullName } | Sort-Object)
        if (($expected -join ',') -cne ($actual -join ',')) {
            throw "Unexpected archive contents: $($package.Name)"
        }
        foreach ($entry in $archive.Entries) {
            $entryStream = $entry.Open()
            $memoryStream = [System.IO.MemoryStream]::new()
            try {
                $entryStream.CopyTo($memoryStream)
                $sourceBytes = [System.IO.File]::ReadAllBytes((Join-Path $projectRoot $entry.FullName))
                if ([Convert]::ToBase64String($sourceBytes) -cne [Convert]::ToBase64String($memoryStream.ToArray())) {
                    throw "Archive differs from source: $($package.Name)/$($entry.FullName)"
                }
                if ($entry.LastWriteTime.Year -ne 2000) {
                    throw "Archive timestamp is not normalized: $($entry.FullName)"
                }
            }
            finally {
                $entryStream.Dispose()
                $memoryStream.Dispose()
            }
        }
    }
    finally {
        $archive.Dispose()
    }
}

$checksumLines = @([System.IO.File]::ReadAllLines((Join-Path $distPath 'SHA256SUMS.txt'), $utf8))
if ($checksumLines.Count -ne $archives.Count) { throw 'Expected one checksum per archive.' }
for ($index = 0; $index -lt $archives.Count; $index++) {
    $packageName = $archives[$index].Name
    $hash = (Get-FileHash -LiteralPath (Join-Path $distPath $packageName) -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($checksumLines[$index] -cne "$hash  $packageName") {
        throw "Checksum mismatch: $packageName"
    }
}
Write-Output 'Package contents, source bytes, license, and SHA-256 checksums verified.'
