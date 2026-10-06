# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Interaksiyon

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$projectRoot = $PSScriptRoot
& (Join-Path $projectRoot 'scripts/check.ps1')
$manifest = Get-Content -LiteralPath (Join-Path $projectRoot 'package.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$sourcePaths = @(& (Join-Path $projectRoot 'scripts/source-files.ps1'))
$distPath = Join-Path $projectRoot 'dist'
$null = New-Item -ItemType Directory -Path $distPath -Force
$baseName = "$($manifest.name)-$($manifest.version)"

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Write-Archive {
    param(
        [string]$ArchiveName,
        [string[]]$SourceFiles
    )

    $archivePath = Join-Path $distPath $ArchiveName
    $temporaryPath = Join-Path $distPath ('.package-' + [Guid]::NewGuid().ToString('N') + '.tmp')
    $stream = $null
    try {
        $stream = [System.IO.File]::Open($temporaryPath, [System.IO.FileMode]::CreateNew)
        $archive = [System.IO.Compression.ZipArchive]::new($stream, [System.IO.Compression.ZipArchiveMode]::Create)
        try {
            $orderedFiles = [string[]]$SourceFiles.Clone()
            [Array]::Sort($orderedFiles, [StringComparer]::Ordinal)
            foreach ($relativePath in $orderedFiles) {
                $sourcePath = Join-Path $projectRoot $relativePath
                $entry = $archive.CreateEntry($relativePath, [System.IO.Compression.CompressionLevel]::Optimal)
                $entry.LastWriteTime = [DateTimeOffset]::new(2000, 1, 1, 0, 0, 0, [TimeSpan]::Zero)
                $entry.ExternalAttributes = 0
                $sourceStream = [System.IO.File]::OpenRead($sourcePath)
                $entryStream = $null
                try {
                    $entryStream = $entry.Open()
                    $sourceStream.CopyTo($entryStream)
                }
                finally {
                    if ($entryStream) { $entryStream.Dispose() }
                    $sourceStream.Dispose()
                }
            }
        }
        finally {
            $archive.Dispose()
        }
        $stream.Dispose()
        $stream = $null
        Move-Item -LiteralPath $temporaryPath -Destination $archivePath -Force
    }
    finally {
        if ($stream) { $stream.Dispose() }
        if (Test-Path -LiteralPath $temporaryPath) {
            Remove-Item -LiteralPath $temporaryPath -Force
        }
    }
    Write-Output "Created: $archivePath"
}

$extensionName = "$baseName.aseprite-extension"
$sourceName = "$baseName-source.zip"
Write-Archive -ArchiveName $extensionName -SourceFiles @('LICENSE', 'main.lua', 'package.json')
Write-Archive -ArchiveName $sourceName -SourceFiles $sourcePaths

$checksumLines = foreach ($name in @($extensionName, $sourceName)) {
    $hash = (Get-FileHash -LiteralPath (Join-Path $distPath $name) -Algorithm SHA256).Hash.ToLowerInvariant()
    "$hash  $name"
}
$utf8 = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText((Join-Path $distPath 'SHA256SUMS.txt'), ($checksumLines -join "`n") + "`n", $utf8)
& (Join-Path $projectRoot 'scripts/check.ps1') -Packages
