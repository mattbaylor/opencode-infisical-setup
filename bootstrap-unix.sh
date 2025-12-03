#!/bin/bash
#
# Bootstrap script to setup OpenCode with Infisical for shared GitHub Copilot authentication.
#
# This script:
# 1. Checks for Infisical CLI installation
# 2. Authenticates to your Infisical instance
# 3. Downloads the sync script from Infisical
# 4. Runs the sync to populate OpenCode's auth.json with GitHub Copilot credentials
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/mattbaylor/opencode-infisical-setup/main/bootstrap-unix.sh | bash
#
# Or download and run with custom domain:
#   curl -fsSL https://raw.githubusercontent.com/mattbaylor/opencode-infisical-setup/main/bootstrap-unix.sh -o bootstrap.sh
#   chmod +x bootstrap.sh
#   INFISICAL_DOMAIN=https://your-domain.com ./bootstrap.sh

set -e

INFISICAL_DOMAIN="${INFISICAL_DOMAIN:-https://infisical.thebaylors.org}"

echo "=== OpenCode + Infisical Bootstrap Script ==="
echo ""

# Detect OS
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [ -f /etc/debian_version ]; then
            echo "debian"
        elif [ -f /etc/redhat-release ]; then
            echo "redhat"
        else
            echo "linux"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    else
        echo "unknown"
    fi
}

OS=$(detect_os)

# Check if Infisical CLI is installed
echo "[1/5] Checking for Infisical CLI..."
if ! command -v infisical &> /dev/null; then
    echo "Infisical CLI not found. Installing..."
    
    case $OS in
        debian)
            echo "Installing via apt..."
            curl -1sLf 'https://dl.cloudsmith.io/public/infisical/infisical-cli/setup.deb.sh' | sudo -E bash
            sudo apt-get update && sudo apt-get install -y infisical
            ;;
        redhat)
            echo "Installing via yum..."
            curl -1sLf 'https://dl.cloudsmith.io/public/infisical/infisical-cli/setup.rpm.sh' | sudo -E bash
            sudo yum install -y infisical
            ;;
        macos)
            if command -v brew &> /dev/null; then
                echo "Installing via Homebrew..."
                brew install infisical/get-cli/infisical
            else
                echo "Homebrew not found. Installing manually..."
                curl -fsSL https://github.com/Infisical/cli/releases/latest/download/infisical_darwin_amd64 -o /tmp/infisical
                chmod +x /tmp/infisical
                sudo mv /tmp/infisical /usr/local/bin/infisical
            fi
            ;;
        *)
            echo "Unsupported OS. Please install Infisical CLI manually from:"
            echo "https://infisical.com/docs/cli/overview"
            exit 1
            ;;
    esac
    
    echo "Infisical CLI installed successfully!"
else
    echo "Infisical CLI found!"
fi

echo ""

# Authenticate to Infisical
echo "[2/5] Authenticating to Infisical..."
echo "Opening browser for authentication..."

if ! infisical login --domain="$INFISICAL_DOMAIN"; then
    echo "Failed to authenticate to Infisical"
    exit 1
fi

echo "Successfully authenticated!"
echo ""

# Initialize Infisical project
echo "[3/5] Initializing Infisical project..."
echo "Please select your organization and the 'OpenCode' project"

if ! infisical init; then
    echo "Failed to initialize Infisical project"
    exit 1
fi

echo "Project initialized!"
echo ""

# Download sync script from Infisical
echo "[4/5] Downloading sync script from Infisical..."

SYNC_SCRIPT_PATH="$HOME/sync-opencode-auth.sh"

if ! infisical secrets get SYNC_SCRIPT_UNIX --plain > "$SYNC_SCRIPT_PATH"; then
    echo "Failed to download sync script from Infisical"
    echo "Make sure the SYNC_SCRIPT_UNIX secret exists in your Infisical project"
    exit 1
fi

chmod +x "$SYNC_SCRIPT_PATH"
echo "Sync script downloaded to: $SYNC_SCRIPT_PATH"
echo ""

# Run the sync script
echo "[5/5] Syncing GitHub Copilot credentials to OpenCode..."

if ! "$SYNC_SCRIPT_PATH"; then
    echo "Failed to sync credentials"
    exit 1
fi

echo ""
echo "=== Setup Complete! ==="
echo ""
echo "Your OpenCode installation is now configured to use shared GitHub Copilot credentials from Infisical."
echo ""
echo "To re-sync credentials in the future (e.g., when tokens are refreshed), run:"
echo "  $SYNC_SCRIPT_PATH"
echo ""
echo "You can now use OpenCode with GitHub Copilot without authentication issues across VMs!"
