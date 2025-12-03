#Requires -Version 5.1
<#
.SYNOPSIS
    Sync OpenCode configuration from GitHub

.DESCRIPTION
    Downloads and installs OpenCode configuration from GitHub repository

.PARAMETER ConfigUrl
    URL to the OpenCode config file (default: GitHub repo template)

.EXAMPLE
    irm https://raw.githubusercontent.com/mattbaylor/opencode-infisical-setup/main/sync-config.ps1 | iex
#>

param(
    [string]$ConfigUrl = "https://raw.githubusercontent.com/mattbaylor/opencode-infisical-setup/main/config-templates/opencode.json"
)

$ErrorActionPreference = "Stop"

Write-Host "=== OpenCode Configuration Sync ===" -ForegroundColor Cyan
Write-Host ""

$configDir = "$env:USERPROFILE\.config\opencode"
$configFile = "$configDir\opencode.json"

# Create config directory if it doesn't exist
if (-not (Test-Path $configDir)) {
    Write-Host "Creating OpenCode config directory: $configDir" -ForegroundColor Yellow
    New-Item -ItemType Directory -Force -Path $configDir | Out-Null
}

# Backup existing config if it exists
if (Test-Path $configFile) {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupFile = "$configFile.backup.$timestamp"
    Write-Host "Backing up existing config to: $backupFile" -ForegroundColor Yellow
    Copy-Item $configFile $backupFile
}

# Download the config
Write-Host "Downloading config from: $ConfigUrl" -ForegroundColor Yellow
try {
    Invoke-WebRequest -Uri $ConfigUrl -OutFile $configFile
} catch {
    Write-Host "Failed to download config from $ConfigUrl" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "OpenCode configuration synced successfully!" -ForegroundColor Green
Write-Host "Config location: $configFile" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Edit the config to customize for your environment:" -ForegroundColor White
Write-Host "   notepad $configFile" -ForegroundColor White
Write-Host ""
Write-Host "2. Set up any required API keys (see config-templates/README.md)" -ForegroundColor White
Write-Host ""
Write-Host "3. Test OpenCode:" -ForegroundColor White
Write-Host "   opencode" -ForegroundColor White
