
$ErrorActionPreference = "Stop"

# Paths relative to this script
$windowsDir = $PSScriptRoot
$repoRoot   = Split-Path $windowsDir -Parent
$destination = Join-Path $repoRoot "nccl_all_arch"
$buildDir    = Join-Path $windowsDir "x64"

# Create destination folder
New-Item -ItemType Directory -Path $destination -Force | Out-Null

# Files to package
$files = @(
    @{
        Source = Join-Path $buildDir "Release\nccl64_134.11.8.dll"
        Name   = "nccl64_134.11.8.dll"
    },
    @{
        Source = Join-Path $buildDir "Release\nccl64_134.11.8.lib"
        Name   = "nccl64_134.11.8.lib"
    },
    @{
        Source = Join-Path $repoRoot "src\nccl.h"
        Name   = "nccl.h"
    }
)

# Verify every source exists before copying anything
foreach ($file in $files) {
    if (-not (Test-Path -LiteralPath $file.Source -PathType Leaf)) {
        throw "Required file not found: $($file.Source)"
    }
}

# Copy files
foreach ($file in $files) {
    Copy-Item -LiteralPath $file.Source `
        -Destination (Join-Path $destination $file.Name) -Force

    Write-Host "Copied $($file.Name)" -ForegroundColor Green
}

# Remove build output only after successful copies
if (Test-Path -LiteralPath $buildDir -PathType Container) {
    Remove-Item -LiteralPath $buildDir -Recurse -Force
    Write-Host "Removed x64 build directory." -ForegroundColor Yellow
}

Write-Host "`nAll files copied successfully!" -ForegroundColor Cyan
Write-Host "Destination: $destination"
