# Install a verified project-local kind binary without changing the global PATH.
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$toolsRoot = Join-Path $projectRoot '.tools'
New-Item -ItemType Directory -Path $toolsRoot -Force | Out-Null
$destination = [System.IO.Path]::GetFullPath((Join-Path $toolsRoot 'kind.exe'))
$downloadPath = [System.IO.Path]::GetFullPath((Join-Path $toolsRoot 'kind.exe.download'))
if (-not $destination.StartsWith($toolsRoot + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'kind destination escaped the project tools directory.'
}

# Digest published with kubernetes-sigs/kind release v0.33.0.
$expectedHash = '4b22adaa135368c5a465d56bbd8e520cbea87272a06ca00b6078e7b81515c9fc'
if ((Test-Path -LiteralPath $destination) -and (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant() -eq $expectedHash) {
    & $destination version
    exit $LASTEXITCODE
}
Invoke-WebRequest -Uri 'https://github.com/kubernetes-sigs/kind/releases/download/v0.33.0/kind-windows-amd64' -OutFile $downloadPath
$actualHash = (Get-FileHash -LiteralPath $downloadPath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actualHash -ne $expectedHash) { throw 'kind checksum mismatch; downloaded binary will not be executed.' }
Move-Item -LiteralPath $downloadPath -Destination $destination -Force
& $destination version
if ($LASTEXITCODE -ne 0) { throw 'Installed kind did not run successfully.' }
