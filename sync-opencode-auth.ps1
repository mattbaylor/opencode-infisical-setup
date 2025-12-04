# Sync GitHub Copilot credentials from Infisical to OpenCode
#
# This script fetches credentials from Infisical and writes them to OpenCode's auth.json
# It's designed to be run automatically via Task Scheduler or manually when needed.

# Colors for output
function Write-Success { Write-Host "✓ $args" -ForegroundColor Green }
function Write-Error { Write-Host "✗ $args" -ForegroundColor Red }
function Write-Info { Write-Host "ℹ $args" -ForegroundColor Yellow }

# Configuration
$OPENCODE_AUTH_DIR = "$env:USERPROFILE\.local\share\opencode"
$OPENCODE_AUTH_FILE = "$OPENCODE_AUTH_DIR\auth.json"

# Check if infisical is available
if (-not (Get-Command infisical -ErrorAction SilentlyContinue)) {
    Write-Error "Infisical CLI not found"
    Write-Info "Please install it from: https://infisical.com/docs/cli/overview"
    exit 1
}

# Check if we're in a directory with .infisical.json
if (-not (Test-Path ".infisical.json")) {
    Write-Error "No .infisical.json found in current directory"
    Write-Info "Please run this script from the directory where you initialized Infisical"
    Write-Info "Or run 'infisical init' to set up the project in this directory"
    exit 1
}

Write-Info "Fetching GitHub Copilot credentials from Infisical..."

# Fetch credentials from Infisical
try {
    $refreshToken = (infisical secrets get GITHUB_COPILOT_REFRESH_TOKEN --plain 2>&1)
    $accessToken = (infisical secrets get GITHUB_COPILOT_ACCESS_TOKEN --plain 2>&1)
    
    if (-not $refreshToken -or -not $accessToken) {
        throw "Failed to fetch credentials"
    }
} catch {
    Write-Error "Failed to fetch credentials from Infisical"
    Write-Info "Make sure you're logged in: infisical login"
    Write-Info "Make sure the secrets exist in your Infisical project"
    exit 1
}

# Extract expiry from access token
# Token format includes "exp=1764799262"
if ($accessToken -match 'exp=(\d+)') {
    $expiresTimestamp = [long]$matches[1] * 1000  # Convert to milliseconds
} else {
    Write-Error "Could not extract expiry from access token"
    $expiresTimestamp = 1764799262000  # Fallback to default
}

# Create directory if it doesn't exist
New-Item -ItemType Directory -Force -Path $OPENCODE_AUTH_DIR | Out-Null

# Build the auth.json content
$authContent = @{
    "github-copilot" = @{
        type = "oauth"
        refresh = $refreshToken
        access = $accessToken
        expires = $expiresTimestamp
    }
} | ConvertTo-Json -Depth 10

# Write to OpenCode's auth.json
$authContent | Out-File -FilePath $OPENCODE_AUTH_FILE -Encoding utf8 -Force

Write-Success "GitHub Copilot credentials synced to OpenCode!"
Write-Info "Auth file: $OPENCODE_AUTH_FILE"

# Calculate expiry date
$expiryDate = [DateTimeOffset]::FromUnixTimeSeconds($expiresTimestamp / 1000).DateTime
Write-Info "Token expires: $expiryDate"

exit 0
