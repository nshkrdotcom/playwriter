# Manual Headed Browser Setup

## The Clean Way

Instead of spawning background processes, do this manually:

### 1. Open PowerShell on Windows
```
Windows Key + R → "powershell" → Enter
```

### 2. Run these commands in PowerShell:
```powershell
cd $env:TEMP
npx playwright run-server --port 3335
```

### 3. You should see:
```
Listening on ws://localhost:3335/
```

### 4. Leave that PowerShell window open

### 5. From WSL, test with:
```bash
PLAYWRIGHT_WS_ENDPOINT=ws://172.19.176.1:3335/ ./playwriter --windows-browser https://google.com
```

This approach:
- ✅ No background processes spawned by our scripts
- ✅ No process cleanup needed  
- ✅ Clear visibility of what's running
- ✅ Easy to stop (just close PowerShell window)
- ✅ No system pollution

## Alternative: Kill Everything and Start Fresh

If you want to clean up completely:

```bash
# Kill any Playwright processes (if needed)
powershell.exe -Command "Get-Process node -ErrorAction SilentlyContinue | Where-Object {$_.CommandLine -like '*playwright*'} | Stop-Process -Force"

# Then follow steps 1-5 above
```