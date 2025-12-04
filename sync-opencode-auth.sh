#!/bin/bash
#
# Sync GitHub Copilot credentials from Infisical to OpenCode
#
# This script fetches credentials from Infisical and writes them to OpenCode's auth.json
# It's designed to be run automatically via cron or manually when needed.
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
OPENCODE_AUTH_DIR="$HOME/.local/share/opencode"
OPENCODE_AUTH_FILE="$OPENCODE_AUTH_DIR/auth.json"

# Function to print colored output
print_error() {
    echo -e "${RED}✗${NC} $1" >&2
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_info() {
    echo -e "${YELLOW}ℹ${NC} $1"
}

# Check if infisical is available
if ! command -v infisical &> /dev/null; then
    print_error "Infisical CLI not found"
    print_info "Please install it from: https://infisical.com/docs/cli/overview"
    exit 1
fi

# Check if we're in a directory with .infisical.json or if user is logged in
if [ ! -f ".infisical.json" ]; then
    print_error "No .infisical.json found in current directory"
    print_info "Please run this script from the directory where you initialized Infisical"
    print_info "Or run 'infisical init' to set up the project in this directory"
    exit 1
fi

print_info "Fetching GitHub Copilot credentials from Infisical..."

# Fetch credentials from Infisical
REFRESH_TOKEN=$(infisical secrets get GITHUB_COPILOT_REFRESH_TOKEN --plain 2>/dev/null)
ACCESS_TOKEN=$(infisical secrets get GITHUB_COPILOT_ACCESS_TOKEN --plain 2>/dev/null)

# Validate credentials were fetched
if [ -z "$REFRESH_TOKEN" ] || [ -z "$ACCESS_TOKEN" ]; then
    print_error "Failed to fetch credentials from Infisical"
    print_info "Make sure you're logged in: infisical login"
    print_info "Make sure the secrets exist in your Infisical project"
    exit 1
fi

# Extract expiry from access token (it's embedded in the token)
# Token format includes "exp=1764799262"
if [[ $ACCESS_TOKEN =~ exp=([0-9]+) ]]; then
    EXPIRES_TIMESTAMP="${BASH_REMATCH[1]}000"  # Convert to milliseconds
else
    print_error "Could not extract expiry from access token"
    EXPIRES_TIMESTAMP="1764799262000"  # Fallback to default
fi

# Create directory if it doesn't exist
mkdir -p "$OPENCODE_AUTH_DIR"

# Write auth.json
cat > "$OPENCODE_AUTH_FILE" << EOF
{
  "github-copilot": {
    "type": "oauth",
    "refresh": "$REFRESH_TOKEN",
    "access": "$ACCESS_TOKEN",
    "expires": $EXPIRES_TIMESTAMP
  }
}
EOF

# Set proper permissions (readable only by owner)
chmod 600 "$OPENCODE_AUTH_FILE"

print_success "GitHub Copilot credentials synced to OpenCode!"
print_info "Auth file: $OPENCODE_AUTH_FILE"
print_info "Token expires: $(date -d @${EXPIRES_TIMESTAMP:0:-3} 2>/dev/null || date -r ${EXPIRES_TIMESTAMP:0:-3} 2>/dev/null || echo 'Unknown')"

exit 0
