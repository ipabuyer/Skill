<#
.SYNOPSIS
    Download and install ipatool Windows executables from official GitHub Releases.

.DESCRIPTION
    Downloads the ipatool Windows (amd64/arm64) tar.gz archives from the official
    ipatool GitHub releases, verifies SHA-256 checksums, and installs the executables
    into OutputDir (default: the "bin" directory next to this script's repository
    root, which is gitignored). Bundled with the IPAbuyer agent skill; keep this
    file ASCII-only so Windows PowerShell 5.1 can parse it without a BOM.

.EXAMPLE
    ./get-ipatool-release.ps1

    Installs into the default "bin" directory at the repository root.

.EXAMPLE
    ./get-ipatool-release.ps1 -OutputDir "$env:LOCALAPPDATA\IPAbuyer\bin"

.EXAMPLE
    ./get-ipatool-release.ps1 -Version 2.4.0 -OutputDir "$env:LOCALAPPDATA\IPAbuyer\bin" -Force
#>
[CmdletBinding()]
param(
    [ValidatePattern('^$|^\d+\.\d+\.\d+$')]
    [string]$Version = '',

    [string]$OutputDir = '',

    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# Prefer the bundled bsdtar: GNU tar (e.g. Git Bash's /usr/bin/tar) misreads
# "D:\..." as a remote host name and fails the extraction.
$tarExecutable = Join-Path $env:SystemRoot 'System32\tar.exe'
if (-not (Test-Path -LiteralPath $tarExecutable -PathType Leaf)) {
    $tarExecutable = 'tar'
}

$architectures = @('amd64', 'arm64')
$latestReleaseApiUrl = 'https://api.github.com/repos/majd/ipatool/releases/latest'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) "ipabuyer-ipatool-$([System.Guid]::NewGuid().ToString('N'))"
$stagedBinaries = @()

function Get-LatestReleaseVersion {
    Write-Host "Resolving the latest ipatool release from $latestReleaseApiUrl"
    $release = Invoke-RestMethod -Uri $latestReleaseApiUrl -Headers @{ 'User-Agent' = 'IPAbuyer ipatool updater' }
    $tagName = [string]$release.tag_name
    if ($tagName -notmatch '^v(?<Version>\d+\.\d+\.\d+)$') {
        throw "Latest release tag has an unsupported format: $tagName"
    }

    return $Matches.Version
}

function Get-ArchiveSha256 {
    param(
        [Parameter(Mandatory)]
        [string]$ChecksumPath
    )

    $checksum = (Get-Content -LiteralPath $ChecksumPath -Raw -Encoding ASCII).Trim()
    if ($checksum -notmatch '^[A-Fa-f0-9]{64}$') {
        throw "Invalid SHA-256 checksum format: $ChecksumPath"
    }

    return $checksum.ToLowerInvariant()
}

function Test-PeFile {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $item = Get-Item -LiteralPath $Path
    if ($item.Length -lt 2) {
        return $false
    }

    $stream = [System.IO.File]::OpenRead($Path)
    try {
        return $stream.ReadByte() -eq 0x4D -and $stream.ReadByte() -eq 0x5A
    }
    finally {
        $stream.Dispose()
    }
}

try {
    # $PSScriptRoot is empty inside param() defaults on Windows PowerShell 5.1,
    # so the default output directory is resolved here instead.
    if ([string]::IsNullOrWhiteSpace($OutputDir)) {
        $OutputDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'bin'
    }

    if ([string]::IsNullOrWhiteSpace($Version)) {
        $Version = Get-LatestReleaseVersion
    }

    $releaseBaseUrl = "https://github.com/majd/ipatool/releases/download/v$Version"
    Write-Host "Using ipatool v$Version"

    $resolvedOutputDir = [System.IO.Path]::GetFullPath($OutputDir)
    [System.IO.Directory]::CreateDirectory($resolvedOutputDir) | Out-Null
    [System.IO.Directory]::CreateDirectory($tempRoot) | Out-Null

    foreach ($architecture in $architectures) {
        $archiveName = "ipatool-$Version-windows-$architecture.tar.gz"
        $checksumName = "$archiveName.sha256sum"
        $executableName = "ipatool-$Version-windows-$architecture.exe"
        $archiveUrl = "$releaseBaseUrl/$archiveName"
        $checksumUrl = "$releaseBaseUrl/$checksumName"
        $architectureTempDir = Join-Path $tempRoot $architecture
        $archivePath = Join-Path $architectureTempDir $archiveName
        $checksumPath = Join-Path $architectureTempDir $checksumName
        $extractDir = Join-Path $architectureTempDir 'extract'
        $expectedExecutablePath = Join-Path $extractDir "bin/$executableName"
        $stagedPath = Join-Path $architectureTempDir "$executableName.staged"

        [System.IO.Directory]::CreateDirectory($architectureTempDir) | Out-Null

        Write-Host "Downloading $archiveUrl"
        Invoke-WebRequest -Uri $archiveUrl -OutFile $archivePath
        Invoke-WebRequest -Uri $checksumUrl -OutFile $checksumPath

        $expectedArchiveHash = Get-ArchiveSha256 -ChecksumPath $checksumPath
        $actualArchiveHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actualArchiveHash -ne $expectedArchiveHash) {
            throw "SHA-256 mismatch for $archiveName. Expected $expectedArchiveHash, got $actualArchiveHash."
        }

        Write-Host "Verified archive SHA-256: $actualArchiveHash"
        [System.IO.Directory]::CreateDirectory($extractDir) | Out-Null
        & $tarExecutable -xzf $archivePath -C $extractDir
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to extract $archiveName."
        }

        if (-not (Test-Path -LiteralPath $expectedExecutablePath -PathType Leaf)) {
            throw "Expected executable was not found in ${archiveName}: bin/$executableName"
        }

        if (-not (Test-PeFile -Path $expectedExecutablePath)) {
            throw "Extracted file is not a valid Windows executable: $expectedExecutablePath"
        }

        Copy-Item -LiteralPath $expectedExecutablePath -Destination $stagedPath
        $stagedBinaries += [PSCustomObject]@{
            Architecture    = $architecture
            ArchiveUrl      = $archiveUrl
            ArchiveHash     = $actualArchiveHash
            ExecutableName  = $executableName
            StagedPath      = $stagedPath
            DestinationPath = Join-Path $resolvedOutputDir $executableName
        }
    }

    foreach ($binary in $stagedBinaries) {
        if ((Test-Path -LiteralPath $binary.DestinationPath) -and -not $Force) {
            throw "Destination already exists: $($binary.DestinationPath). Re-run with -Force to replace it."
        }
    }

    foreach ($binary in $stagedBinaries) {
        $destinationTempPath = "$($binary.DestinationPath).$([System.Guid]::NewGuid().ToString('N')).tmp"
        Copy-Item -LiteralPath $binary.StagedPath -Destination $destinationTempPath
        Move-Item -LiteralPath $destinationTempPath -Destination $binary.DestinationPath -Force

        $executableHash = (Get-FileHash -LiteralPath $binary.DestinationPath -Algorithm SHA256).Hash.ToLowerInvariant()
        Write-Host "Installed $($binary.Architecture): $($binary.DestinationPath)"
        Write-Host "Executable SHA-256: $executableHash"
    }
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
