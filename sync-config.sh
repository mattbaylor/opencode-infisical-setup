#!/bin/bash
#
# Sync OpenCode configuration from GitHub
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/mattbaylor/opencode-infisical-setup/main/sync-config.sh | bash
#
# Or with custom config URL:
#   CONFIG_URL=https://your-url.com/opencode.json bash sync-config.sh

set -e

CONFIG_URL="${CONFIG_URL:-https://raw.githubusercontent.com/mattbaylor/opencode-infisical-setup/main/config-templates/opencode.json}"
OPENCODE_CONFIG_DIR="${HOME}/.config/opencode"
OPENCODE_CONFIG_FILE="${OPENCODE_CONFIG_DIR}/opencode.json"

echo "=== OpenCode Configuration Sync ==="
echo ""

# Create config directory if it doesn't exist
if [ ! -d "$OPENCODE_CONFIG_DIR" ]; then
    echo "Creating OpenCode config directory: $OPENCODE_CONFIG_DIR"
    mkdir -p "$OPENCODE_CONFIG_DIR"
fi

# Backup existing config if it exists
if [ -f "$OPENCODE_CONFIG_FILE" ]; then
    BACKUP_FILE="${OPENCODE_CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    echo "Backing up existing config to: $BACKUP_FILE"
    cp "$OPENCODE_CONFIG_FILE" "$BACKUP_FILE"
fi

# Download the config
echo "Downloading config from: $CONFIG_URL"
if ! curl -fsSL "$CONFIG_URL" -o "$OPENCODE_CONFIG_FILE"; then
    echo "Failed to download config from $CONFIG_URL"
    exit 1
fi

echo ""
echo "OpenCode configuration synced successfully!"
echo "Config location: $OPENCODE_CONFIG_FILE"
echo ""
echo "Next steps:"
echo "1. Edit the config to customize for your environment:"
echo "   nano $OPENCODE_CONFIG_FILE"
echo ""
echo "2. Set up any required API keys (see config-templates/README.md)"
echo ""
echo "3. Test OpenCode:"
echo "   opencode"
