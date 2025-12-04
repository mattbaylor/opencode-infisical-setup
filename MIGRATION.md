# Migration & Update Guide

## What Changed in v2.0

### Major Improvement: Sync Scripts Now in GitHub

**Before (v1.0):**
- Sync scripts stored in Infisical as secrets (`SYNC_SCRIPT_UNIX`, `SYNC_SCRIPT_WINDOWS`)
- Hard to update scripts
- Infisical cluttered with code

**After (v2.0):**
- Sync scripts stored in this GitHub repo
- Easy to update (just push to GitHub)
- Infisical only stores credentials
- Bootstrap scripts download sync scripts from GitHub

### What You Need to Do

#### If You're Using Windows (Already Working)

✅ **Nothing!** Your setup keeps working.

**Optional improvements:**
1. Re-run the bootstrap to get the improved scripts:
   ```powershell
   cd C:\Projects  # or your project directory
   irm https://raw.githubusercontent.com/mattbaylor/opencode-infisical-setup/main/bootstrap-windows.ps1 | iex
   ```

2. This will:
   - Download the new sync script from GitHub (better error handling)
   - Keep your existing Infisical config
   - Update the scheduled task

#### If You're Setting Up Linux

Just run the bootstrap script - it works now!

```bash
cd ~/projects  # or your project directory
curl -fsSL https://raw.githubusercontent.com/mattbaylor/opencode-infisical-setup/main/bootstrap-unix.sh | bash
```

### Infisical Cleanup (Optional)

You can remove the old sync scripts from Infisical if you want:

1. Go to `https://infisical.thebaylors.org`
2. Open your "OpenCode" project
3. Delete these secrets (they're not needed anymore):
   - `SYNC_SCRIPT_UNIX` ❌ (now in GitHub)
   - `SYNC_SCRIPT_WINDOWS` ❌ (now in GitHub)

4. **Keep these secrets** (still required!):
   - `GITHUB_COPILOT_ACCESS_TOKEN` ✅
   - `GITHUB_COPILOT_REFRESH_TOKEN` ✅

## New Features

### 1. Automatic Expiry Extraction

The sync scripts now automatically extract the expiry timestamp from your access token. No more hardcoded timestamps!

**Before:**
```json
"expires": 1764799262000  // Hardcoded, needs manual updates
```

**After:**
```json
"expires": 1764799262000  // Automatically extracted from token
```

### 2. Better Error Handling

**Unix script (`sync-opencode-auth.sh`):**
- ✅ Color-coded output (green success, red errors, yellow info)
- ✅ Checks for `.infisical.json` before running
- ✅ Validates credentials were fetched
- ✅ Sets proper file permissions (600)
- ✅ Shows token expiry date

**Windows script (`sync-opencode-auth.ps1`):**
- ✅ Color-coded output
- ✅ Checks for `.infisical.json` before running
- ✅ Validates credentials were fetched
- ✅ Shows token expiry date

### 3. Improved Bootstrap Scripts

Both Windows and Linux bootstrap scripts now:
- ✅ Check if already logged in
- ✅ Detect existing project config
- ✅ Download sync scripts from GitHub (not Infisical)
- ✅ Better error messages with troubleshooting hints
- ✅ Create wrapper scripts for cron/Task Scheduler
- ✅ Work from any directory (saves current dir)

## Testing Your Setup

### Windows

1. **Check sync script:**
   ```powershell
   & "$env:USERPROFILE\sync-opencode-auth.ps1"
   ```
   Should show green checkmarks and success message.

2. **Check auth file:**
   ```powershell
   Get-Content "$env:USERPROFILE\.local\share\opencode\auth.json"
   ```
   Should show valid GitHub Copilot credentials.

3. **Check scheduled task:**
   ```powershell
   Get-ScheduledTask -TaskName "OpenCode-Sync"
   ```
   Should show task is Ready.

### Linux/Mac

1. **Check sync script:**
   ```bash
   ~/sync-opencode-auth.sh
   ```
   Should show green checkmarks and success message.

2. **Check auth file:**
   ```bash
   cat ~/.local/share/opencode/auth.json
   ```
   Should show valid GitHub Copilot credentials.

3. **Check cron job:**
   ```bash
   crontab -l | grep sync-opencode
   ```
   Should show daily 3 AM job.

## Troubleshooting Migration Issues

### "No .infisical.json found"

You need to be in the directory where you ran the bootstrap script.

**Fix:**
```bash
# Find where .infisical.json is
find ~ -name ".infisical.json" 2>/dev/null

# Or re-run bootstrap from your project directory
cd ~/projects
# ... run bootstrap again
```

### "Failed to fetch credentials"

Make sure the secret names are exactly right in Infisical:
- `GITHUB_COPILOT_ACCESS_TOKEN` (not `ACCESS_TOKEN` or anything else)
- `GITHUB_COPILOT_REFRESH_TOKEN` (not `REFRESH_TOKEN` or anything else)

### Windows Script Not Running

Make sure execution policy allows it:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Automatic Sync Not Working

**Windows:**
Check task scheduler logs:
```powershell
Get-Content "$env:USERPROFILE\opencode-sync.log" -Tail 20
```

**Linux:**
Check cron logs:
```bash
tail -f ~/opencode-sync.log
```

## Comparison: Old vs New

### Infisical Secrets

**Before:**
```
GITHUB_COPILOT_ACCESS_TOKEN
GITHUB_COPILOT_REFRESH_TOKEN
SYNC_SCRIPT_UNIX            ← No longer needed
SYNC_SCRIPT_WINDOWS         ← No longer needed
```

**After:**
```
GITHUB_COPILOT_ACCESS_TOKEN
GITHUB_COPILOT_REFRESH_TOKEN
```

### File Structure

**Before:**
```
~/sync-opencode-auth.sh     (downloaded from Infisical)
~/.local/share/opencode/
  └── auth.json
.infisical.json
```

**After:**
```
~/sync-opencode-auth.sh     (downloaded from GitHub)
~/sync-opencode-wrapper.sh  (for cron)
~/.local/share/opencode/
  └── auth.json
.infisical.json
~/opencode-sync.log         (automatic sync logs)
```

## Rollback (If Needed)

If you need to go back to the old way:

1. Your credentials are still in Infisical, so you're safe
2. The old bootstrap scripts are still in git history
3. Just checkout the previous version of this repo

But realistically, the new version is strictly better!

## Questions?

- **Do I need to update my Windows machines?** No, but recommended for better error handling
- **Do my credentials need to change?** No! Same credentials work
- **Will this break my existing setup?** No! Backwards compatible
- **Do I need to re-authenticate?** No! Uses existing Infisical login

## Summary

**TL;DR:**
1. Sync scripts moved from Infisical to GitHub
2. Better error handling and user experience
3. Automatic expiry extraction
4. Windows and Linux now work the same way
5. Your existing credentials still work fine
6. Optional: Clean up old SYNC_SCRIPT_* secrets from Infisical
