#Requires -Version 5.1
<#
.SYNOPSIS
    Bootstrap script to setup OpenCode with Infisical for shared GitHub Copilot authentication.

.DESCRIPTION
    This script:
    1. Checks for Infisical CLI installation
    2. Authenticates to your Infisical instance
    3. Downloads the sync script from Infisical
    4. Runs the sync to populate OpenCode's auth.json with GitHub Copilot credentials

.PARAMETER InfisicalDomain
    The domain of your Infisical instance (default: https://infisical.thebaylors.org)

.PARAMETER SyncConfig
    Also sync OpenCode configuration from GitHub (default: $true)

.EXAMPLE
    irm https://raw.githubusercontent.com/mattbaylor/opencode-infisical-setup/main/bootstrap-windows.ps1 | iex
#>

param(
    [string]$InfisicalDomain = "https://infisical.thebaylors.org",
    [bool]$SyncConfig = $true
)

$ErrorActionPreference = "Stop"

Write-Host "=== OpenCode + Infisical Bootstrap Script ===" -ForegroundColor Cyan
Write-Host ""

# Check if Infisical CLI is installed
Write-Host "[1/5] Checking for Infisical CLI..." -ForegroundColor Yellow
$infisicalInstalled = Get-Command infisical -ErrorAction SilentlyContinue

if (-not $infisicalInstalled) {
    Write-Host "Infisical CLI not found. Installing..." -ForegroundColor Yellow
    
    try {
        # Download Infisical CLI
        $tempDir = "$env:TEMP\infisical-install"
        New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
        
        Write-Host "Downloading Infisical CLI..." -ForegroundColor Yellow
        Invoke-WebRequest -Uri "https://github.com/Infisical/cli/releases/latest/download/infisical_windows_amd64.exe" -OutFile "$tempDir\infisical.exe"
        
        # Install to user directory
        $installDir = "$env:LOCALAPPDATA\infisical"
        New-Item -ItemType Directory -Force -Path $installDir | Out-Null
        Move-Item -Path "$tempDir\infisical.exe" -Destination "$installDir\infisical.exe" -Force
        
        # Add to PATH
        $currentPath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::User)
        if ($currentPath -notlike "*$installDir*") {
            [Environment]::SetEnvironmentVariable("Path", "$currentPath;$installDir", [EnvironmentVariableTarget]::User)
            $env:Path += ";$installDir"
        }
        
        Write-Host "Infisical CLI installed successfully!" -ForegroundColor Green
    } catch {
        Write-Host "Failed to install Infisical CLI: $_" -ForegroundColor Red
        Write-Host "Please install manually from: https://infisical.com/docs/cli/overview" -ForegroundColor Yellow
        exit 1
    }
}

Write-Host "Infisical CLI found!" -ForegroundColor Green
Write-Host ""

# Authenticate to Infisical
Write-Host "[2/5] Authenticating to Infisical..." -ForegroundColor Yellow
Write-Host "Opening browser for authentication..." -ForegroundColor Cyan

try {
    & infisical login --domain=$InfisicalDomain
    if ($LASTEXITCODE -ne 0) {
        throw "Infisical login failed"
    }
    Write-Host "Successfully authenticated!" -ForegroundColor Green
} catch {
    Write-Host "Failed to authenticate to Infisical: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Initialize Infisical project
Write-Host "[3/5] Initializing Infisical project..." -ForegroundColor Yellow
Write-Host "Please select your organization and the 'OpenCode' project" -ForegroundColor Cyan

try {
    & infisical init
    if ($LASTEXITCODE -ne 0) {
        throw "Infisical init failed"
    }
    Write-Host "Project initialized!" -ForegroundColor Green
} catch {
    Write-Host "Failed to initialize Infisical project: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Download sync script from Infisical
Write-Host "[4/5] Downloading sync script from Infisical..." -ForegroundColor Yellow

try {
    $syncScript = & infisical secrets get SYNC_SCRIPT_WINDOWS --plain
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to retrieve sync script from Infisical"
    }
    
    $syncScriptPath = "$env:USERPROFILE\sync-opencode-auth.ps1"
    $syncScript | Out-File -FilePath $syncScriptPath -Encoding utf8 -Force
    
    Write-Host "Sync script downloaded to: $syncScriptPath" -ForegroundColor Green
} catch {
    Write-Host "Failed to download sync script: $_" -ForegroundColor Red
    Write-Host "Make sure the SYNC_SCRIPT_WINDOWS secret exists in your Infisical project" -ForegroundColor Yellow
    exit 1
}

Write-Host ""

# Run the sync script
Write-Host "[5/5] Syncing GitHub Copilot credentials to OpenCode..." -ForegroundColor Yellow

try {
    & $syncScriptPath
    if ($LASTEXITCODE -ne 0) {
        throw "Sync script execution failed"
    }
} catch {
    Write-Host "Failed to sync credentials: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "=== Setup Complete! ===" -ForegroundColor Green
Write-Host ""
Write-Host "Your OpenCode installation is now configured to use shared GitHub Copilot credentials from Infisical." -ForegroundColor Cyan
Write-Host ""

# Optionally sync OpenCode config
if ($SyncConfig) {
    Write-Host "[Bonus] Syncing OpenCode configuration from GitHub..." -ForegroundColor Yellow
    try {
        $configSyncScript = Invoke-WebRequest -Uri "https://raw.githubusercontent.com/mattbaylor/opencode-infisical-setup/main/sync-config.ps1" -UseBasicParsing
        Invoke-Expression $configSyncScript.Content
    } catch {
        Write-Host "Failed to sync OpenCode config (non-fatal): $_" -ForegroundColor Yellow
        Write-Host "You can sync it manually later with:" -ForegroundColor Yellow
        Write-Host "  irm https://raw.githubusercontent.com/mattbaylor/opencode-infisical-setup/main/sync-config.ps1 | iex" -ForegroundColor White
    }
    Write-Host ""
}

# Set up scheduled auto-sync
Write-Host "[6/6] Setting up automatic daily credential sync..." -ForegroundColor Yellow

try {
    # Get the current directory where .infisical.json exists
    $infisicalConfigPath = Get-ChildItem -Path . -Filter ".infisical.json" -ErrorAction SilentlyContinue
    
    if ($infisicalConfigPath) {
        $workingDir = (Get-Location).Path
    } else {
        # Fallback to user's Documents folder
        $workingDir = "$env:USERPROFILE\Documents"
    }
    
    # Create wrapper script that changes to the correct directory
    $wrapperScript = @"
Set-Location -Path '$workingDir'
& '$syncScriptPath'
"@
    
    $wrapperScriptPath = "$env:USERPROFILE\sync-opencode-wrapper.ps1"
    $wrapperScript | Out-File -FilePath $wrapperScriptPath -Encoding utf8 -Force
    
    # Create scheduled task
    $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-WindowStyle Hidden -File `"$wrapperScriptPath`""
    $trigger = New-ScheduledTaskTrigger -Daily -At 3am
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
    
    # Remove existing task if it exists
    $existingTask = Get-ScheduledTask -TaskName "Sync OpenCode Credentials" -ErrorAction SilentlyContinue
    if ($existingTask) {
        Unregister-ScheduledTask -TaskName "Sync OpenCode Credentials" -Confirm:$false
    }
    
    Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "Sync OpenCode Credentials" -Description "Daily sync of GitHub Copilot credentials from Infisical" -Settings $settings -User $env:USERNAME | Out-Null
    
    Write-Host "Scheduled task created! Credentials will auto-sync daily at 3:00 AM" -ForegroundColor Green
} catch {
    Write-Host "Failed to create scheduled task (non-fatal): $_" -ForegroundColor Yellow
    Write-Host "You can create it manually if needed" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== All Done! ===" -ForegroundColor Green
Write-Host ""
Write-Host "To manually re-sync credentials anytime, run:" -ForegroundColor Yellow
Write-Host "  & '$syncScriptPath'" -ForegroundColor White
Write-Host ""
Write-Host "You can now use OpenCode with GitHub Copilot without authentication issues across VMs!" -ForegroundColor Green
