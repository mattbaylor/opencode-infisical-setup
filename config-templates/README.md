# OpenCode Configuration Templates

This directory contains configuration templates for quickly setting up OpenCode with various AI model providers.

## Available Templates

### `opencode.json`
The main OpenCode configuration file with pre-configured providers:

- **Ollama Local** - Local Ollama instance (127.0.0.1:11434)
- **Ollama Remote** - Remote Ollama server (192.168.11.80:11434)
- **Grok (xAI)** - Grok models from X.AI (requires API key)

## Quick Setup

### 1. Copy the configuration

**Mac/Linux:**
```bash
# Download and install the config
curl -fsSL https://raw.githubusercontent.com/mattbaylor/opencode-infisical-setup/main/config-templates/opencode.json -o ~/.config/opencode/opencode.json
```

**Windows (PowerShell):**
```powershell
# Create config directory if it doesn't exist
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.config\opencode"

# Download and install the config
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/mattbaylor/opencode-infisical-setup/main/config-templates/opencode.json" -OutFile "$env:USERPROFILE\.config\opencode\opencode.json"
```

### 2. Customize for your environment

Edit the configuration to match your setup:

```bash
# Mac/Linux
nano ~/.config/opencode/opencode.json

# Windows
notepad "$env:USERPROFILE\.config\opencode\opencode.json"
```

**Common customizations:**

- Update `ollama-remote` baseURL to your Ollama server's IP
- Add/remove models based on what you have installed
- Configure additional providers

### 3. Set up API keys (if using Grok or other cloud providers)

**For Grok (xAI):**

1. Get your API key from https://console.x.ai/
2. Set the environment variable:

**Mac/Linux:**
```bash
echo 'export XAI_API_KEY="your-api-key-here"' >> ~/.bashrc
source ~/.bashrc
```

**Windows (PowerShell):**
```powershell
[Environment]::SetEnvironmentVariable("XAI_API_KEY", "your-api-key-here", [EnvironmentVariableTarget]::User)
```

**Or store in Infisical:**
```bash
# Add to Infisical
infisical secrets set XAI_API_KEY="your-api-key-here"

# Run OpenCode with Infisical
infisical run -- opencode
```

## Adding More Providers

### DeepSeek (Free/Cheap)
```json
"deepseek": {
  "npm": "@ai-sdk/openai-compatible",
  "name": "DeepSeek",
  "options": {
    "baseURL": "https://api.deepseek.com/v1",
    "apiKey": "${DEEPSEEK_API_KEY}"
  },
  "models": {
    "deepseek-coder": {
      "name": "DeepSeek Coder"
    },
    "deepseek-chat": {
      "name": "DeepSeek Chat"
    }
  }
}
```

### Groq (Free tier available)
```json
"groq": {
  "npm": "@ai-sdk/openai-compatible",
  "name": "Groq",
  "options": {
    "baseURL": "https://api.groq.com/openai/v1",
    "apiKey": "${GROQ_API_KEY}"
  },
  "models": {
    "llama-3.1-70b-versatile": {
      "name": "Llama 3.1 70B"
    },
    "llama-3.1-8b-instant": {
      "name": "Llama 3.1 8B Instant"
    },
    "mixtral-8x7b-32768": {
      "name": "Mixtral 8x7B"
    }
  }
}
```

### OpenRouter (Access to many models)
```json
"openrouter": {
  "npm": "@ai-sdk/openai-compatible",
  "name": "OpenRouter",
  "options": {
    "baseURL": "https://openrouter.ai/api/v1",
    "apiKey": "${OPENROUTER_API_KEY}"
  },
  "models": {
    "meta-llama/llama-3.1-70b-instruct": {
      "name": "Llama 3.1 70B"
    },
    "anthropic/claude-3.5-sonnet": {
      "name": "Claude 3.5 Sonnet"
    },
    "deepseek/deepseek-coder": {
      "name": "DeepSeek Coder"
    }
  }
}
```

## Managing Configs Across Machines

### Store in Infisical

Store your entire OpenCode config in Infisical:

```bash
# Upload your config
infisical secrets set OPENCODE_CONFIG "$(cat ~/.config/opencode/opencode.json)"

# On other machines, download it
infisical secrets get OPENCODE_CONFIG --plain > ~/.config/opencode/opencode.json
```

### Use the sync script

The bootstrap scripts can automatically sync your config from Infisical. See the main README for details.

## Tips

1. **Use environment variables** for API keys instead of hardcoding them
2. **Store configs in Infisical** to keep all machines in sync
3. **Test providers** with a simple query before relying on them
4. **Keep local models** as fallback when cloud providers have issues
5. **Mix local and cloud** - use fast local models for iteration, cloud for complex tasks

## Resources

- [OpenCode Documentation](https://opencode.ai/docs)
- [Ollama Models](https://ollama.com/library)
- [Grok API Docs](https://docs.x.ai/api)
- [Groq API](https://console.groq.com/)
- [DeepSeek](https://platform.deepseek.com/)
- [OpenRouter](https://openrouter.ai/)
