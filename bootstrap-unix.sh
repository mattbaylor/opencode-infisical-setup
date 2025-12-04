#!/bin/bash
#
# Bootstrap script to setup OpenCode with Infisical for shared GitHub Copilot authentication.
#
# This script:
# 1. Installs Infisical CLI (if needed)
# 2. Authenticates to your Infisical instance
# 3. Initializes the Infisical project
# 4. Downloads the sync script from GitHub
# 5. Runs the sync to populate OpenCode's auth.json
# 6. Sets up automatic daily sync via cron
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/mattbaylor/opencode-infisical-setup/main/bootstrap-unix.sh | bash
#
# Or download and run with custom domain:
#   curl -fsSL https://raw.githubusercontent.com/mattbaylor/opencode-infisical-setup/main/bootstrap-unix.sh -o bootstrap.sh
#   chmod +x bootstrap.sh
#   INFISICAL_DOMAIN=https://your-domain.com ./bootstrap.sh

set -e

# Configuration
INFISICAL_DOMAIN="${INFISICAL_DOMAIN:-https://infisical.thebaylors.org}"
GITHUB_RAW_URL="https://raw.githubusercontent.com/mattbaylor/opencode-infisical-setup/main"
SYNC_SCRIPT_PATH="$HOME/sync-opencode-auth.sh"
WRAPPER_SCRIPT_PATH="$HOME/sync-opencode-wrapper.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Helper functions
print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

print_step() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1" >&2
}

print_info() {
    echo -e "${YELLOW}ℹ${NC} $1"
}

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

print_header "OpenCode + Infisical Bootstrap"

print_info "This script will configure OpenCode to use shared GitHub Copilot credentials"
print_info "from your Infisical instance at: $INFISICAL_DOMAIN"
echo ""

# Step 1: Check/Install Infisical CLI
print_header "[1/6] Checking Infisical CLI"

# Minimum required version
REQUIRED_VERSION="0.40.0"

# Function to compare versions
version_ge() {
    # Returns 0 (true) if $1 >= $2
    printf '%s\n%s' "$2" "$1" | sort -V -C
}

# Check if installed and version
NEEDS_INSTALL=false
if command -v infisical &> /dev/null; then
    INFISICAL_VERSION=$(infisical --version 2>&1 | grep -oP 'v?\K[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || echo "0.0.0")
    print_info "Infisical CLI found: v$INFISICAL_VERSION"
    
    if version_ge "$INFISICAL_VERSION" "$REQUIRED_VERSION"; then
        print_step "Version is recent enough (>= v$REQUIRED_VERSION)"
    else
        print_info "Version is too old (< v$REQUIRED_VERSION), will reinstall"
        NEEDS_INSTALL=true
        
        # Remove old version
        if [ "$OS" = "debian" ]; then
            print_info "Removing old version..."
            sudo apt-get remove -y infisical 2>/dev/null || true
            sudo rm -f /etc/apt/sources.list.d/infisical*.list
        elif [ "$OS" = "redhat" ]; then
            sudo yum remove -y infisical 2>/dev/null || true
        fi
    fi
else
    print_info "Infisical CLI not found. Installing..."
    NEEDS_INSTALL=true
fi

if [ "$NEEDS_INSTALL" = true ]; then
    print_info "Installing latest Infisical CLI..."
    
    # Use direct GitHub releases download (most reliable method)
    case $OS in
        debian|linux)
            print_info "Downloading from GitHub releases..."
            ARCH=$(uname -m)
            if [ "$ARCH" = "x86_64" ]; then
                ARCH="amd64"
            elif [ "$ARCH" = "aarch64" ]; then
                ARCH="arm64"
            fi
            
            # Get latest version
            LATEST_VERSION=$(curl -s https://api.github.com/repos/Infisical/cli/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
            print_info "Latest version: $LATEST_VERSION"
            
            # Download and extract tarball
            DOWNLOAD_URL="https://github.com/Infisical/cli/releases/download/${LATEST_VERSION}/cli_${LATEST_VERSION#v}_linux_${ARCH}.tar.gz"
            if curl -fsSL "$DOWNLOAD_URL" | sudo tar -xz -C /usr/local/bin; then
                print_step "Infisical CLI installed successfully!"
                
                # Ensure /usr/local/bin is in PATH
                export PATH="/usr/local/bin:$PATH"
                hash -r  # Clear bash's command cache
                
                # Verify installation
                if command -v infisical &> /dev/null; then
                    NEW_VERSION=$(infisical --version 2>&1 | grep -oP 'v?\K[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || echo "unknown")
                    print_info "Installed version: v$NEW_VERSION"
                else
                    print_error "Installation succeeded but infisical not found in PATH"
                    print_info "Try running: export PATH=\"/usr/local/bin:\$PATH\" && hash -r"
                    exit 1
                fi
            else
                print_error "Failed to download from GitHub"
                exit 1
            fi
            ;;
        macos)
            if command -v brew &> /dev/null; then
                print_info "Installing via Homebrew..."
                brew install infisical/get-cli/infisical
            else
                print_error "Homebrew not found. Please install Homebrew first:"
                print_info "https://brew.sh"
                exit 1
            fi
            ;;
        *)
            print_error "Unsupported OS. Please install Infisical CLI manually:"
            print_info "https://infisical.com/docs/cli/overview"
            exit 1
            ;;
    esac
fi

# Step 2: Authenticate to Infisical
print_header "[2/6] Authenticating to Infisical"

# Try to get a token to verify we're logged in
print_info "Checking authentication status..."
if infisical user get token --domain="$INFISICAL_DOMAIN" --silent 2>/dev/null 1>/dev/null; then
    # Successfully got a token - we're logged in
    print_step "Already logged in to Infisical"
else
    # Not logged in - need to authenticate
    
    # Detect if running interactively (has TTY) or piped/SSH
    if [ -t 0 ] && [ -t 1 ]; then
        # Interactive terminal - can use browser or interactive login
        print_info "Not logged in. Attempting authentication..."
        print_info "Domain: $INFISICAL_DOMAIN"
        echo ""
        
        # Try login with -i flag if over SSH (detect SSH_CONNECTION or SSH_TTY)
        if [ -n "$SSH_CONNECTION" ] || [ -n "$SSH_TTY" ] || [ -n "$SSH_CLIENT" ]; then
            print_info "SSH session detected - using interactive CLI login (no browser)"
            if ! infisical login --domain="$INFISICAL_DOMAIN" -i; then
                print_error "Authentication failed"
                exit 1
            fi
        else
            # Local terminal - try browser-based login
            if ! infisical login --domain="$INFISICAL_DOMAIN"; then
                print_error "Authentication failed"
                exit 1
            fi
        fi
        
        print_step "Successfully authenticated!"
    else
        # Non-interactive (piped through curl, cron, etc.)
        print_error "Not logged in to Infisical"
        print_info ""
        print_info "This script requires authentication but is running non-interactively."
        print_info "Please login first, then run this script:"
        print_info ""
        print_info "  # Login to Infisical"
        print_info "  infisical login --domain=$INFISICAL_DOMAIN -i"
        print_info ""
        print_info "  # Then download and run this script"
        print_info "  curl -fsSL https://raw.githubusercontent.com/mattbaylor/opencode-infisical-setup/main/bootstrap-unix.sh -o bootstrap.sh"
        print_info "  bash bootstrap.sh"
        print_info ""
        exit 1
    fi
fi

# Step 3: Initialize Infisical project
print_header "[3/6] Initializing Infisical Project"

if [ -f ".infisical.json" ]; then
    print_step "Infisical project already initialized in this directory"
    print_info "Using existing configuration"
else
    print_info "Please select your organization and the 'OpenCode' project"
    echo ""
    
    if ! infisical init --domain="$INFISICAL_DOMAIN"; then
        print_error "Failed to initialize Infisical project"
        print_info "Make sure the 'OpenCode' project exists in your Infisical instance"
        exit 1
    fi
    
    print_step "Project initialized!"
fi

# Save current directory for wrapper script
CURRENT_DIR=$(pwd)

# Step 4: Download sync script from GitHub
print_header "[4/6] Downloading Sync Script"

print_info "Downloading from: $GITHUB_RAW_URL/sync-opencode-auth.sh"

if ! curl -fsSL "$GITHUB_RAW_URL/sync-opencode-auth.sh" -o "$SYNC_SCRIPT_PATH"; then
    print_error "Failed to download sync script from GitHub"
    print_info "Please check your internet connection and try again"
    exit 1
fi

chmod +x "$SYNC_SCRIPT_PATH"
print_step "Sync script downloaded to: $SYNC_SCRIPT_PATH"

# Step 5: Run initial sync
print_header "[5/6] Syncing GitHub Copilot Credentials"

print_info "Running initial credential sync..."
echo ""

# Run sync from the project directory
cd "$CURRENT_DIR"
if ! "$SYNC_SCRIPT_PATH"; then
    print_error "Failed to sync credentials"
    print_info "Common issues:"
    print_info "  - Credentials not set in Infisical"
    print_info "  - Not in the directory with .infisical.json"
    print_info "  - Not logged in to Infisical"
    exit 1
fi

# Step 6: Set up automatic daily sync
print_header "[6/6] Setting Up Automatic Sync"

print_info "Creating wrapper script for cron..."

# Create wrapper script that changes to the right directory
cat > "$WRAPPER_SCRIPT_PATH" << EOF
#!/bin/bash
# Wrapper script for cron to ensure we're in the right directory
cd "$CURRENT_DIR" || exit 1
"$SYNC_SCRIPT_PATH" >> "$HOME/opencode-sync.log" 2>&1
EOF

chmod +x "$WRAPPER_SCRIPT_PATH"

# Add to crontab if not already present
if crontab -l 2>/dev/null | grep -q "sync-opencode-wrapper.sh"; then
    print_step "Cron job already exists"
    crontab -l | grep "sync-opencode-wrapper.sh"
else
    print_info "Adding daily sync to crontab (3:00 AM)..."
    (crontab -l 2>/dev/null; echo "0 3 * * * $WRAPPER_SCRIPT_PATH") | crontab -
    print_step "Cron job added successfully!"
    print_info "Logs will be written to: $HOME/opencode-sync.log"
fi

# Optional: Sync OpenCode configuration
if [ -n "$SYNC_CONFIG" ] && [ "$SYNC_CONFIG" = "true" ]; then
    print_header "[Bonus] Syncing OpenCode Configuration"
    if curl -fsSL "$GITHUB_RAW_URL/sync-config.sh" | bash; then
        print_step "OpenCode configuration synced!"
    else
        print_info "Skipped config sync (non-fatal)"
    fi
fi

# Success summary
print_header "Setup Complete!"

echo -e "${GREEN}Your OpenCode installation is now configured!${NC}"
echo ""
echo "Summary:"
echo "  ✓ Infisical CLI installed and authenticated"
echo "  ✓ Project initialized in: $CURRENT_DIR"
echo "  ✓ Sync script installed: $SYNC_SCRIPT_PATH"
echo "  ✓ GitHub Copilot credentials synced"
echo "  ✓ Automatic daily sync configured (3:00 AM)"
echo ""
echo "Usage:"
echo "  - Manual sync anytime: $SYNC_SCRIPT_PATH"
echo "  - View sync logs: tail -f $HOME/opencode-sync.log"
echo "  - Manage cron: crontab -e"
echo ""
print_info "You can now use OpenCode with GitHub Copilot without session conflicts!"
echo ""
