#Requires -Version 5.1
<#
.SYNOPSIS
    Bootstrap script to setup OpenCode with Infisical for shared GitHub Copilot authentication.

.DESCRIPTION
    This script:
    1. Installs Infisical CLI (if needed)
    2. Authenticates to your Infisical instance
    3. Initializes the Infisical project
    4. Downloads the sync script from GitHub (not Infisical!)
    5. Runs the sync to populate OpenCode's auth.json
    6. Sets up automatic daily sync via Task Scheduler

.PARAMETER InfisicalDomain
    The domain of your Infisical instance (default: https://infisical.thebaylors.org)

.PARAMETER SyncConfig
    Also sync OpenCode configuration from GitHub (default: $false)

.EXAMPLE
    irm https://raw.githubusercontent.com/mattbaylor/opencode-infisical-setup/main/bootstrap-windows.ps1 | iex
    
.EXAMPLE
    $env:INFISICAL_DOMAIN = "https://your-domain.com"
    irm https://raw.githubusercontent.com/mattbaylor/opencode-infisical-setup/main/bootstrap-windows.ps1 | iex
#>

param(
    [string]$InfisicalDomain = $(if ($env:INFISICAL_DOMAIN) { $env:INFISICAL_DOMAIN } else { "https://infisical.thebaylors.org" }),
    [bool]$SyncConfig = $false
)

$ErrorActionPreference = "Stop"

# Configuration
$GITHUB_RAW_URL = "https://raw.githubusercontent.com/mattbaylor/opencode-infisical-setup/main"
$SYNC_SCRIPT_PATH = "$env:USERPROFILE\sync-opencode-auth.ps1"
$WRAPPER_SCRIPT_PATH = "$env:USERPROFILE\sync-opencode-wrapper.ps1"

# Colors
function Write-Header { 
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Blue
    Write-Host $args -ForegroundColor Blue
    Write-Host "========================================" -ForegroundColor Blue
    Write-Host ""
}

function Write-Step { Write-Host "✓ $args" -ForegroundColor Green }
function Write-ErrorMsg { Write-Host "✗ $args" -ForegroundColor Red }
function Write-Info { Write-Host "ℹ $args" -ForegroundColor Yellow }

Write-Header "OpenCode + Infisical Bootstrap"

Write-Info "This script will configure OpenCode to use shared GitHub Copilot credentials"
Write-Info "from your Infisical instance at: $InfisicalDomain"
Write-Host ""

# Step 1: Check/Install Infisical CLI
Write-Header "[1/6] Checking Infisical CLI"

if (Get-Command infisical -ErrorAction SilentlyContinue) {
    try {
        $version = (infisical --version 2>&1 | Select-Object -First 1)
        Write-Step "Infisical CLI already installed: $version"
    } catch {
        Write-Step "Infisical CLI already installed"
    }
} else {
    Write-Info "Infisical CLI not found. Installing..."
    
    try {
        # Try winget first
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Write-Info "Installing via winget..."
            winget install --id Infisical.CLI -e --silent --accept-package-agreements --accept-source-agreements
        }
        # Try scoop
        elseif (Get-Command scoop -ErrorAction SilentlyContinue) {
            Write-Info "Installing via scoop..."
            scoop install infisical
        }
        # Fallback to manual installation
        else {
            Write-Info "Installing manually..."
            $tempDir = "$env:TEMP\infisical-install"
            New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
            
            Invoke-WebRequest -Uri "https://github.com/Infisical/cli/releases/latest/download/infisical_windows_amd64.exe" -OutFile "$tempDir\infisical.exe"
            
            $installDir = "$env:LOCALAPPDATA\infisical"
            New-Item -ItemType Directory -Force -Path $installDir | Out-Null
            Move-Item -Path "$tempDir\infisical.exe" -Destination "$installDir\infisical.exe" -Force
            
            # Add to PATH
            $currentPath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::User)
            if ($currentPath -notlike "*$installDir*") {
                [Environment]::SetEnvironmentVariable("Path", "$currentPath;$installDir", [EnvironmentVariableTarget]::User)
                $env:Path += ";$installDir"
            }
        }
        
        # Refresh PATH
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        
        if (Get-Command infisical -ErrorAction SilentlyContinue) {
            Write-Step "Infisical CLI installed successfully!"
        } else {
            throw "Installation failed"
        }
    } catch {
        Write-ErrorMsg "Failed to install Infisical CLI"
        Write-Info "Please install manually from: https://infisical.com/docs/cli/overview"
        exit 1
    }
}

# Step 2: Authenticate to Infisical
Write-Header "[2/6] Authenticating to Infisical"

try {
    $userInfo = infisical user 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Step "Already logged in to Infisical"
        $emailLine = $userInfo | Select-String 'email' | Select-Object -First 1
        if ($emailLine) {
            Write-Info "Current user: $emailLine"
        }
    } else {
        throw "Not logged in"
    }
} catch {
    Write-Info "Opening browser for authentication to: $InfisicalDomain"
    
    infisical login --domain="$InfisicalDomain"
    
    if ($LASTEXITCODE -ne 0) {
        Write-ErrorMsg "Failed to authenticate to Infisical"
        Write-Info "Please check that $InfisicalDomain is accessible"
        exit 1
    }
    
    Write-Step "Successfully authenticated!"
}

# Step 3: Initialize Infisical project
Write-Header "[3/6] Initializing Infisical Project"

if (Test-Path ".infisical.json") {
    Write-Step "Infisical project already initialized in this directory"
    Write-Info "Using existing configuration"
} else {
    Write-Info "Please select your organization and the 'OpenCode' project"
    Write-Host ""
    
    infisical init --domain="$InfisicalDomain"
    
    if ($LASTEXITCODE -ne 0) {
        Write-ErrorMsg "Failed to initialize Infisical project"
        Write-Info "Make sure the 'OpenCode' project exists in your Infisical instance"
        exit 1
    }
    
    Write-Step "Project initialized!"
}

# Save current directory for wrapper script
$CURRENT_DIR = (Get-Location).Path

# Step 4: Download sync script from GitHub
Write-Header "[4/6] Downloading Sync Script"

Write-Info "Downloading from: $GITHUB_RAW_URL/sync-opencode-auth.ps1"

try {
    Invoke-WebRequest -Uri "$GITHUB_RAW_URL/sync-opencode-auth.ps1" -OutFile $SYNC_SCRIPT_PATH -UseBasicParsing
    Write-Step "Sync script downloaded to: $SYNC_SCRIPT_PATH"
} catch {
    Write-ErrorMsg "Failed to download sync script from GitHub"
    Write-Info "Please check your internet connection and try again"
    Write-Info "Error: $_"
    exit 1
}

# Step 5: Run initial sync
Write-Header "[5/6] Syncing GitHub Copilot Credentials"

Write-Info "Running initial credential sync..."
Write-Host ""

# Run sync from the project directory
Set-Location $CURRENT_DIR

try {
    & $SYNC_SCRIPT_PATH
    if ($LASTEXITCODE -ne 0) { throw "Sync failed with exit code $LASTEXITCODE" }
} catch {
    Write-ErrorMsg "Failed to sync credentials"
    Write-Info "Common issues:"
    Write-Info "  - Credentials not set in Infisical (GITHUB_COPILOT_ACCESS_TOKEN, GITHUB_COPILOT_REFRESH_TOKEN)"
    Write-Info "  - Not in the directory with .infisical.json"
    Write-Info "  - Not logged in to Infisical"
    Write-Info "Error: $_"
    exit 1
}

# Step 6: Set up automatic daily sync
Write-Header "[6/6] Setting Up Automatic Sync"

Write-Info "Creating wrapper script for Task Scheduler..."

# Create wrapper script that changes to the right directory
$wrapperContent = @"
# Wrapper script for Task Scheduler to ensure we're in the right directory
Set-Location '$CURRENT_DIR'
& '$SYNC_SCRIPT_PATH' >> '$env:USERPROFILE\opencode-sync.log' 2>&1
"@

$wrapperContent | Out-File -FilePath $WRAPPER_SCRIPT_PATH -Encoding utf8 -Force

# Check if task already exists
$taskName = "OpenCode-Sync"
$existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

if ($existingTask) {
    Write-Step "Scheduled task already exists"
    Write-Info "Task: $taskName"
} else {
    Write-Info "Creating scheduled task (daily at 3:00 AM)..."
    
    try {
        $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$WRAPPER_SCRIPT_PATH`""
        $trigger = New-ScheduledTaskTrigger -Daily -At 3:00AM
        $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType S4U -RunLevel Highest
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
        
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings | Out-Null
        
        Write-Step "Scheduled task created successfully!"
        Write-Info "Logs will be written to: $env:USERPROFILE\opencode-sync.log"
    } catch {
        Write-Info "Failed to create scheduled task (non-fatal): $_"
        Write-Info "You can create it manually if needed"
    }
}

# Optional: Sync OpenCode configuration
if ($SyncConfig) {
    Write-Header "[Bonus] Syncing OpenCode Configuration"
    try {
        $configSyncScript = Invoke-WebRequest -Uri "$GITHUB_RAW_URL/sync-config.ps1" -UseBasicParsing
        Invoke-Expression $configSyncScript.Content
        Write-Step "OpenCode configuration synced!"
    } catch {
        Write-Info "Failed to sync OpenCode config (non-fatal): $_"
        Write-Info "You can sync it manually later with:"
        Write-Info "  irm $GITHUB_RAW_URL/sync-config.ps1 | iex"
    }
}

# Success summary
Write-Header "Setup Complete!"

Write-Host "Your OpenCode installation is now configured!" -ForegroundColor Green
Write-Host ""
Write-Host "Summary:"
Write-Host "  ✓ Infisical CLI installed and authenticated"
Write-Host "  ✓ Project initialized in: $CURRENT_DIR"
Write-Host "  ✓ Sync script installed: $SYNC_SCRIPT_PATH"
Write-Host "  ✓ GitHub Copilot credentials synced"
Write-Host "  ✓ Automatic daily sync configured (3:00 AM)"
Write-Host ""
Write-Host "Usage:"
Write-Host "  - Manual sync anytime: & ""$SYNC_SCRIPT_PATH"""
Write-Host "  - View sync logs: Get-Content ""$env:USERPROFILE\opencode-sync.log"" -Tail 20"
Write-Host "  - Manage task: taskschd.msc"
Write-Host ""
Write-Info "You can now use OpenCode with GitHub Copilot without session conflicts!"
Write-Host ""
