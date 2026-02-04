# Playwriter Windows Server Launcher
# Run from Windows PowerShell

param(
    [int]$Port = 3337,
    [switch]$Install
)

$ServerDir = "$env:TEMP\playwriter-server"

# Create directory if needed
if (!(Test-Path $ServerDir)) {
    New-Item -ItemType Directory -Path $ServerDir | Out-Null
}

# Install dependencies if requested or missing
if ($Install -or !(Test-Path "$ServerDir\node_modules")) {
    Write-Host "Installing Playwright..."
    Push-Location $ServerDir

    # Create package.json
    @'
{
  "name": "playwriter-server",
  "private": true,
  "dependencies": {
    "playwright": "^1.40.0"
  }
}
'@ | Out-File -FilePath "package.json" -Encoding UTF8

    npm install
    npx playwright install chromium

    Pop-Location
    Write-Host "Installation complete."
}

# Create server script
$ServerScript = @'
const { chromium } = require('playwright');
const PORT = parseInt(process.argv[2]) || 3337;

async function main() {
  console.log(`Starting Playwright server on port ${PORT}...`);
  const server = await chromium.launchServer({ headless: false, port: PORT, host: '0.0.0.0' });
  console.log(`Server running at: ${server.wsEndpoint()}`);
  console.log('Press Ctrl+C to stop');
  process.on('SIGINT', async () => { await server.close(); process.exit(0); });
  process.on('SIGTERM', async () => { await server.close(); process.exit(0); });
}
main().catch(err => { console.error(err); process.exit(1); });
'@

$ServerScript | Out-File -FilePath "$ServerDir\server.js" -Encoding UTF8

# Start server
Write-Host "Starting server on port $Port..."
Write-Host "Connect from WSL with: ws://localhost:$Port/"
Push-Location $ServerDir
node server.js $Port
Pop-Location
