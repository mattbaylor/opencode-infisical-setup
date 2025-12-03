# OpenCode + Infisical Setup

**Solve GitHub Copilot authentication collisions across multiple machines/VMs when using OpenCode.**

## The Problem

When using OpenCode with GitHub Copilot across multiple machines or VMs, each authentication creates a new session token that invalidates previous sessions. This causes:

- `TypeError: undefined is not an object (evaluating 'response.headers')` errors
- Workflow interruptions
- Constant re-authentication requests

## The Solution

This repository provides a turnkey solution using [Infisical](https://infisical.com) to centrally manage and distribute GitHub Copilot credentials across all your machines.

### Architecture

1. **Infisical Server** - Self-hosted secret manager stores GitHub Copilot tokens
2. **Sync Scripts** - Stored in Infisical, injected into each machine's OpenCode config
3. **Bootstrap Scripts** - One-command setup for new machines

## Prerequisites

- A self-hosted Infisical instance (see [Setup Infisical Server](#setup-infisical-server) below)
- OpenCode installed on your machine(s)
- An active GitHub Copilot subscription

## Quick Start

### For New Machines

**IMPORTANT:** Run the bootstrap script from a project/working directory (not your home directory). This ensures the Infisical project context is saved correctly.

**Windows (PowerShell):**
```powershell
# Navigate to a project directory first
cd C:\Projects  # or wherever you want to work
irm https://raw.githubusercontent.com/mattbaylor/opencode-infisical-setup/main/bootstrap-windows.ps1 | iex
```

**Linux/Mac (Bash):**
```bash
# Navigate to a project directory first
cd ~/projects  # or wherever you want to work
curl -fsSL https://raw.githubusercontent.com/mattbaylor/opencode-infisical-setup/main/bootstrap-unix.sh | bash
```

The bootstrap script will:
1. Install Infisical CLI (if needed)
2. Authenticate to your Infisical instance
3. Initialize project (creates `.infisical.json` in current directory)
4. Download and configure the sync script
5. Sync GitHub Copilot credentials to OpenCode
6. Sync OpenCode configuration from GitHub (includes Grok, Ollama, etc.)
7. **Set up automatic daily sync at 3:00 AM**

### Sync OpenCode Configuration Only

If you just want to sync your OpenCode configuration (model providers) without setting up Infisical:

**Windows:**
```powershell
irm https://raw.githubusercontent.com/mattbaylor/opencode-infisical-setup/main/sync-config.ps1 | iex
```

**Linux/Mac:**
```bash
curl -fsSL https://raw.githubusercontent.com/mattbaylor/opencode-infisical-setup/main/sync-config.sh | bash
```

This will download a pre-configured `opencode.json` with:
- Ollama Local (127.0.0.1:11434)
- Ollama Remote (192.168.11.80:11434)
- Grok (xAI) - requires API key
- Ready to add more providers (DeepSeek, Groq, OpenRouter, etc.)

See [config-templates/README.md](config-templates/README.md) for customization options.

### Re-sync Credentials

When credentials need to be refreshed:

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

On a machine where OpenCode is already authenticated with GitHub Copilot:

**Mac/Linux:**
```bash
cat ~/.local/share/opencode/auth.json
```

**Windows:**
```powershell
Get-Content "$env:USERPROFILE\.local\share\opencode\auth.json"
```

From the output, add these secrets to your Infisical project:

1. **Secret Key:** `GITHUB_COPILOT_REFRESH_TOKEN`  
   **Value:** The `refresh` token value

2. **Secret Key:** `GITHUB_COPILOT_ACCESS_TOKEN`  
   **Value:** The `access` token value

### 3. Add Sync Scripts

Add these two secrets to store the sync scripts:

**Secret Key:** `SYNC_SCRIPT_WINDOWS`  
**Value:**
```powershell
# Fetch secrets from Infisical
$refreshToken = (infisical secrets get GITHUB_COPILOT_REFRESH_TOKEN --plain)
$accessToken = (infisical secrets get GITHUB_COPILOT_ACCESS_TOKEN --plain)

# Build the auth.json content
$authContent = @{
    "github-copilot" = @{
        type = "oauth"
        refresh = $refreshToken
        access = $accessToken
        expires = 1764799262000
    }
} | ConvertTo-Json -Depth 10

# Write to OpenCode's auth.json
$authPath = "$env:USERPROFILE\.local\share\opencode\auth.json"
New-Item -ItemType Directory -Force -Path (Split-Path $authPath) | Out-Null
$authContent | Out-File -FilePath $authPath -Encoding utf8 -Force

Write-Host "GitHub Copilot credentials synced from Infisical to OpenCode!" -ForegroundColor Green
```

**Secret Key:** `SYNC_SCRIPT_UNIX`  
**Value:**
```bash
#!/bin/bash
REFRESH_TOKEN=$(infisical secrets get GITHUB_COPILOT_REFRESH_TOKEN --plain)
ACCESS_TOKEN=$(infisical secrets get GITHUB_COPILOT_ACCESS_TOKEN --plain)

mkdir -p ~/.local/share/opencode

cat > ~/.local/share/opencode/auth.json << EOF
{
  "github-copilot": {
    "type": "oauth",
    "refresh": "$REFRESH_TOKEN",
    "access": "$ACCESS_TOKEN",
    "expires": 1764799262000
  }
}
EOF

echo "GitHub Copilot credentials synced from Infisical to OpenCode!"
```

## How It Works

1. **One machine authenticates** with GitHub Copilot normally
2. **Extract tokens** from that machine's OpenCode config
3. **Store in Infisical** for centralized management
4. **All other machines** pull tokens from Infisical
5. **No session collisions** - all machines share the same credentials

## Troubleshooting

### Bootstrap script fails to authenticate

Make sure your Infisical domain is correct:

```powershell
# Windows - custom domain
$env:INFISICAL_DOMAIN = "https://your-infisical-domain.com"
irm https://raw.githubusercontent.com/mattbaylor/opencode-infisical-setup/main/bootstrap-windows.ps1 | iex
```

```bash
# Linux/Mac - custom domain
INFISICAL_DOMAIN=https://your-infisical-domain.com bash <(curl -fsSL https://raw.githubusercontent.com/mattbaylor/opencode-infisical-setup/main/bootstrap-unix.sh)
```

### Sync script not found in Infisical

Make sure you've added the `SYNC_SCRIPT_WINDOWS` or `SYNC_SCRIPT_UNIX` secrets to your Infisical project as described in [Initial Infisical Configuration](#initial-infisical-configuration).

### OpenCode still asks for authentication

1. Check that auth.json was created:
   - Windows: `Get-Content "$env:USERPROFILE\.local\share\opencode\auth.json"`
   - Linux/Mac: `cat ~/.local/share/opencode/auth.json`

2. Verify it contains the `github-copilot` section with tokens

3. Re-run the sync script

### Tokens expired

When GitHub Copilot tokens expire:

1. Authenticate OpenCode on one machine normally
2. Extract the new tokens from that machine's auth.json
3. Update the tokens in Infisical
4. Re-run sync scripts on all other machines

## Security Considerations

- **Never commit** `.env` files or tokens to version control
- **Restrict access** to your Infisical instance (firewall, VPN, etc.)
- **Use HTTPS** for all Infisical access
- **Rotate tokens** when team members leave or keys are compromised
- **Backup** your Infisical database regularly

## License

MIT

## Credits

Created to solve OpenCode + GitHub Copilot multi-VM authentication issues using Infisical for secure secret management.
