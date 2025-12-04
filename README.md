# OpenCode + Infisical Setup

**The bulletproof solution for sharing GitHub Copilot credentials across all your machines without session conflicts.**

## The Problem

When using OpenCode with GitHub Copilot across multiple machines or VMs, each authentication creates a new session token that invalidates previous sessions. This causes:

- `TypeError: undefined is not an object (evaluating 'response.headers')` errors
- Workflow interruptions
- Constant re-authentication requests

## The Solution

This repository provides a fully automatic, robust solution using [Infisical](https://infisical.com) to centrally manage and distribute GitHub Copilot credentials across all your machines.

### How It Works

1. **Infisical Server** - Self-hosted secret manager stores your GitHub Copilot tokens
2. **Sync Scripts** - Stored in this GitHub repo, pull credentials from Infisical
3. **Bootstrap Scripts** - One-command setup for new machines
4. **Automatic Sync** - Daily credential refresh (3:00 AM) via cron/Task Scheduler

**Key Improvement:** Sync scripts are now in GitHub (not Infisical), making updates easy and keeping Infisical focused on secrets only.

## Quick Start

### Prerequisites

- A self-hosted Infisical instance (see [Setup Infisical Server](#setup-infisical-server) below)
- OpenCode installed on your machine(s)
- An active GitHub Copilot subscription

### One-Time Setup: Add Credentials to Infisical

On a machine where GitHub Copilot already works:

**Mac/Linux:**
```bash
cat ~/.local/share/opencode/auth.json
```

**Windows:**
```powershell
Get-Content "$env:USERPROFILE\.local\share\opencode\auth.json"
```

From the output, add these **two secrets** to your Infisical "OpenCode" project:

1. **Secret Key:** `GITHUB_COPILOT_REFRESH_TOKEN`  
   **Value:** The `refresh` token value (starts with `ghu_`)

2. **Secret Key:** `GITHUB_COPILOT_ACCESS_TOKEN`  
   **Value:** The `access` token value (starts with `tid=`)

**That's it for Infisical!** You no longer need to store the sync scripts in Infisical.

### Setup New Machines

**IMPORTANT:** 
1. Navigate to a project/working directory first (not your home directory). This ensures `.infisical.json` is saved correctly.
2. For remote/SSH sessions, login to Infisical FIRST before running the bootstrap script.

**Windows (PowerShell):**
```powershell
# Navigate to a project directory first
cd C:\Projects  # or wherever you want to work

# Run bootstrap (interactive - will open browser)
irm https://raw.githubusercontent.com/mattbaylor/opencode-infisical-setup/main/bootstrap-windows.ps1 | iex
```

**Linux/Mac (Bash) - Local Machine:**
```bash
# Navigate to a project directory first
cd ~/projects  # or wherever you want to work

# Run bootstrap (interactive - will open browser)
curl -fsSL https://raw.githubusercontent.com/mattbaylor/opencode-infisical-setup/main/bootstrap-unix.sh | bash
```

**Linux/Mac (Bash) - Remote/SSH Session:**
```bash
# Navigate to a project directory first
cd ~/projects  # or wherever you want to work

# Step 1: Login first (required for SSH sessions)
infisical login --domain=https://infisical.thebaylors.org -i

# Step 2: Download and run bootstrap
curl -fsSL https://raw.githubusercontent.com/mattbaylor/opencode-infisical-setup/main/bootstrap-unix.sh -o bootstrap.sh
bash bootstrap.sh
```

The bootstrap script will:
1. ✓ Install Infisical CLI (if needed)
2. ✓ Authenticate to your Infisical instance
3. ✓ Initialize project (creates `.infisical.json`)
4. ✓ Download sync script from GitHub
5. ✓ Sync GitHub Copilot credentials to OpenCode
6. ✓ Set up automatic daily sync at 3:00 AM

### Manual Re-sync

When you need to refresh credentials manually:

**Windows:**
```powershell
& "$env:USERPROFILE\sync-opencode-auth.ps1"
```

**Linux/Mac:**
```bash
~/sync-opencode-auth.sh
```

## Setup Infisical Server

If you don't have an Infisical instance yet, here's how to set one up on TrueNAS SCALE (or any Docker host):

### 1. Create Docker Compose Setup

```bash
# Create directory structure
sudo mkdir -p /mnt/Main/infisical/{postgres-data,redis-data,infisical-config}
cd /mnt/Main/infisical

# Generate secrets
export POSTGRES_PASSWORD=$(openssl rand -hex 32)
export ENCRYPTION_KEY=$(openssl rand -hex 16)
export AUTH_SECRET=$(openssl rand -hex 16)
export REDIS_PASSWORD=$(openssl rand -hex 32)

# Create .env file
cat > .env << EOF
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
ENCRYPTION_KEY=${ENCRYPTION_KEY}
AUTH_SECRET=${AUTH_SECRET}
REDIS_PASSWORD=${REDIS_PASSWORD}
SMTP_HOST=your-smtp-host
SMTP_PORT=587
SMTP_USERNAME=your-smtp-username
SMTP_PASSWORD=your-smtp-password
SMTP_FROM_ADDRESS=infisical@yourdomain.com
SMTP_FROM_NAME=Infisical
EOF
```

### 2. Create docker-compose.yml

```yaml
services:
  postgres:
    image: postgres:15-alpine
    container_name: infisical-postgres
    restart: unless-stopped
    environment:
      POSTGRES_USER: infisical
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: infisical
    volumes:
      - ./postgres-data:/var/lib/postgresql/data
    networks:
      - infisical-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U infisical"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    container_name: infisical-redis
    restart: unless-stopped
    command: redis-server --requirepass ${REDIS_PASSWORD}
    volumes:
      - ./redis-data:/data
    networks:
      - infisical-network
    healthcheck:
      test: ["CMD", "redis-cli", "--raw", "incr", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  infisical:
    image: infisical/infisical:latest
    container_name: infisical-server
    restart: unless-stopped
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    environment:
      - DB_CONNECTION_URI=postgres://infisical:${POSTGRES_PASSWORD}@postgres:5432/infisical
      - REDIS_URL=redis://default:${REDIS_PASSWORD}@redis:6379
      - ENCRYPTION_KEY=${ENCRYPTION_KEY}
      - AUTH_SECRET=${AUTH_SECRET}
      - SITE_URL=https://infisical.yourdomain.com
      - SMTP_HOST=${SMTP_HOST}
      - SMTP_PORT=${SMTP_PORT}
      - SMTP_SECURE=false
      - SMTP_USERNAME=${SMTP_USERNAME}
      - SMTP_PASSWORD=${SMTP_PASSWORD}
      - SMTP_FROM_ADDRESS=${SMTP_FROM_ADDRESS}
      - SMTP_FROM_NAME=${SMTP_FROM_NAME}
    ports:
      - "8085:8080"
    volumes:
      - ./infisical-config:/app/data
    networks:
      - infisical-network

networks:
  infisical-network:
    driver: bridge
```

### 3. Start Services

```bash
docker compose up -d
```

### 4. Configure Reverse Proxy (Caddy example)

```caddy
infisical.yourdomain.com {
    reverse_proxy http://192.168.11.171:8085 {
        header_up Host {http.request.host}
        header_up X-Real-IP {remote_host}
    }
    encode gzip
}
```

## Initial Infisical Configuration

### 1. Create Account & Project

1. Navigate to `https://infisical.yourdomain.com`
2. Create an admin account
3. Create an organization
4. Create a project named "OpenCode" (type: Secrets Management)

### 2. Add GitHub Copilot Credentials

See [One-Time Setup](#one-time-setup-add-credentials-to-infisical) above.

You only need to add **two secrets**:
- `GITHUB_COPILOT_REFRESH_TOKEN`
- `GITHUB_COPILOT_ACCESS_TOKEN`

**No need to add sync scripts to Infisical anymore** - they're stored in this GitHub repo!

## Sync OpenCode Configuration (Optional)

If you want to sync your OpenCode model provider configuration across machines:

**Windows:**
```powershell
irm https://raw.githubusercontent.com/mattbaylor/opencode-infisical-setup/main/sync-config.ps1 | iex
```

**Linux/Mac:**
```bash
curl -fsSL https://raw.githubusercontent.com/mattbaylor/opencode-infisical-setup/main/sync-config.sh | bash
```

This downloads a pre-configured `opencode.json` with:
- Ollama Local (127.0.0.1:11434)
- Ollama Remote (192.168.11.80:11434)
- Grok (xAI) - requires API key

See [config-templates/README.md](config-templates/README.md) for customization options.

## Troubleshooting

### Bootstrap script fails to authenticate

Make sure your Infisical domain is correct:

**Windows:**
```powershell
$env:INFISICAL_DOMAIN = "https://your-infisical-domain.com"
irm https://raw.githubusercontent.com/mattbaylor/opencode-infisical-setup/main/bootstrap-windows.ps1 | iex
```

**Linux/Mac:**
```bash
INFISICAL_DOMAIN=https://your-infisical-domain.com bash <(curl -fsSL https://raw.githubusercontent.com/mattbaylor/opencode-infisical-setup/main/bootstrap-unix.sh)
```

### OpenCode still asks for authentication

1. Check that auth.json was created:
   - Windows: `Get-Content "$env:USERPROFILE\.local\share\opencode\auth.json"`
   - Linux/Mac: `cat ~/.local/share/opencode/auth.json`

2. Verify it contains the `github-copilot` section with tokens

3. Re-run the sync script

### Sync script errors

**"No .infisical.json found"**
- You need to run the sync script from the directory where you ran bootstrap
- Or cd to that directory first

**"Failed to fetch credentials"**
- Make sure you're logged in: `infisical login`
- Verify secrets exist in Infisical: `infisical secrets list`
- Check secret names match exactly: `GITHUB_COPILOT_ACCESS_TOKEN` and `GITHUB_COPILOT_REFRESH_TOKEN`

### Tokens expired

When GitHub Copilot tokens expire:

1. Authenticate OpenCode on one machine normally (let it get new tokens)
2. Extract the new tokens from that machine's `~/.local/share/opencode/auth.json`
3. Update the tokens in Infisical (via web UI)
4. Re-run sync scripts on all other machines

## What's New

### v2.0 Improvements

✅ **Sync scripts now in GitHub** (not Infisical)  
✅ **Automatic expiry extraction** from access token  
✅ **Better error handling** with colored output  
✅ **Validation checks** at every step  
✅ **Clearer documentation**  
✅ **Windows & Linux parity** - both work the same way  

### Migration from v1.0

If you have the old setup with sync scripts in Infisical:

1. Just run the new bootstrap script - it will download from GitHub
2. (Optional) Remove old `SYNC_SCRIPT_UNIX` and `SYNC_SCRIPT_WINDOWS` secrets from Infisical
3. Keep `GITHUB_COPILOT_ACCESS_TOKEN` and `GITHUB_COPILOT_REFRESH_TOKEN` - those are still needed!

## Security Considerations

- **Never commit** `.env` files or tokens to version control
- **Restrict access** to your Infisical instance (firewall, VPN, etc.)
- **Use HTTPS** for all Infisical access
- **Rotate tokens** when team members leave or keys are compromised
- **Backup** your Infisical database regularly
- **`.infisical.json`** should be in `.gitignore`

## File Locations

After setup:

```
~/.local/share/opencode/
  └── auth.json                      # OpenCode credentials

~/sync-opencode-auth.sh              # Sync script (Linux/Mac)
~/sync-opencode-wrapper.sh           # Cron wrapper (Linux/Mac)

%USERPROFILE%\sync-opencode-auth.ps1        # Sync script (Windows)
%USERPROFILE%\sync-opencode-wrapper.ps1     # Task wrapper (Windows)

.infisical.json                      # Infisical project config (in project dir)
```

## License

MIT

## Credits

Created to solve OpenCode + GitHub Copilot multi-VM authentication issues using Infisical for secure secret management.
