<#
.SYNOPSIS
    Build ipatool from source via a Go module proxy, without accessing GitHub.

.DESCRIPTION
    Downloads the ipatool module zip from a Go module proxy (default: goproxy.cn,
    reachable from mainland China), then builds it locally with the Go toolchain
    (Go 1.25 or newer, as declared in ipatool's go.mod). Version is injected with
    the same ldflags the official release workflow uses. Bundled with the IPAbuyer
    agent skill; keep this file ASCII-only so Windows PowerShell 5.1 can parse it
    without a BOM.

.EXAMPLE
    ./build-ipatool.ps1

    Builds the latest version for this machine's architecture into the default
    "bin" directory at the repository root.

.EXAMPLE
    ./build-ipatool.ps1 -Version 2.4.0 -OutputDir "$env:LOCALAPPDATA\IPAbuyer\bin"
#>
[CmdletBinding()]
param(
    [ValidatePattern('^$|^\d+\.\d+\.\d+$')]
    [string]$Version = '',

    [string]$Proxy = 'https://goproxy.cn',

    [string]$OutputDir = '',

    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$modulePath = 'github.com/majd/ipatool/v2'
$minGoVersion = [version]'1.25.0'
$tempRoot = $null

function Get-DefaultArchitecture {
    $value = $env:PROCESSOR_ARCHITECTURE
    if ($value -eq 'ARM64') {
        return 'arm64'
    }
    if ($value -eq 'AMD64') {
        return 'amd64'
    }
    # A 32-bit process on 64-bit Windows reports x86; the real architecture is in the WOW64 variable.
    if ($value -eq 'x86' -and $env:PROCESSOR_ARCHITEW6432 -eq 'ARM64') {
        return 'arm64'
    }
    if ($value -eq 'x86' -and $env:PROCESSOR_ARCHITEW6432 -eq 'AMD64') {
        return 'amd64'
    }
    throw "Unsupported CPU architecture: $value"
}

try {
    $goVersionText = & go version
} catch {
    throw "Go is not installed or not on PATH. Install Go $minGoVersion or newer (for example: scoop install go)."
}

if ($goVersionText -match 'go(\d+\.\d+(\.\d+)?)') {
    $goVersion = [version]$Matches[1]
    if ($goVersion -lt $minGoVersion) {
        throw "Go $minGoVersion or newer is required (found $goVersion)."
    }
} else {
    throw "Unable to parse the output of 'go version': $goVersionText"
}

try {
    # $PSScriptRoot is empty inside param() defaults on Windows PowerShell 5.1,
    # so the default output directory is resolved here instead.
    if ([string]::IsNullOrWhiteSpace($OutputDir)) {
        $OutputDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'bin'
    }

    if ([string]::IsNullOrWhiteSpace($Version)) {
        Write-Host "Resolving the latest ipatool version from $Proxy"
        $list = Invoke-RestMethod -Uri "$Proxy/$modulePath/@v/list"
        $Version = ($list -split "`r?`n" |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ -match '^v\d+\.\d+\.\d+$' } |
            ForEach-Object { [version]$_.TrimStart('v') } |
            Sort-Object -Descending |
            Select-Object -First 1).ToString()
    }

    $architecture = Get-DefaultArchitecture

    $resolvedOutputDir = [System.IO.Path]::GetFullPath($OutputDir)
    [System.IO.Directory]::CreateDirectory($resolvedOutputDir) | Out-Null

    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) "ipabuyer-ipatool-build-$([System.Guid]::NewGuid().ToString('N'))"
    [System.IO.Directory]::CreateDirectory($tempRoot) | Out-Null

    $archivePath = Join-Path $tempRoot "ipatool-$Version.zip"
    $extractDir = Join-Path $tempRoot 'extract'
    $moduleDir = Join-Path $extractDir "$modulePath@v$Version"

    $zipUrl = "$Proxy/$modulePath/@v/v$Version.zip"
    Write-Host "Downloading module source from $zipUrl"
    Invoke-WebRequest -Uri $zipUrl -OutFile $archivePath
    Expand-Archive -Path $archivePath -DestinationPath $extractDir -Force

    if (-not (Test-Path -LiteralPath (Join-Path $moduleDir 'main.go') -PathType Leaf)) {
        throw "Module source was not found after extraction: $moduleDir"
    }

    $destinationPath = Join-Path $resolvedOutputDir "ipatool-$Version-windows-$architecture.exe"
    if ((Test-Path -LiteralPath $destinationPath) -and -not $Force) {
        throw "Destination already exists: $destinationPath. Re-run with -Force to replace it."
    }

    Write-Host "Building ipatool v$Version for windows/$architecture with GOPROXY=$Proxy,direct"
    $destinationTempPath = "$destinationPath.$([System.Guid]::NewGuid().ToString('N')).tmp"
    Push-Location $moduleDir
    try {
        $env:GOPROXY = "$Proxy,direct"
        & go build -trimpath -ldflags "-s -w -X $modulePath/cmd.version=$Version" -o $destinationTempPath .
        if ($LASTEXITCODE -ne 0) {
            throw "go build failed with exit code $LASTEXITCODE."
        }
    } finally {
        Pop-Location
    }
    Move-Item -LiteralPath $destinationTempPath -Destination $destinationPath -Force

    $executableHash = (Get-FileHash -LiteralPath $destinationPath -Algorithm SHA256).Hash.ToLowerInvariant()
    Write-Host "Built windows/${architecture}: $destinationPath"
    Write-Host "Executable SHA-256: $executableHash"
}
finally {
    if ($tempRoot -and (Test-Path -LiteralPath $tempRoot)) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
