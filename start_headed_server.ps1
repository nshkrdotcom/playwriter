# Start Playwright server in headed mode
param(
    [int]$Port = 3333
)

Write-Host "Starting Playwright server in HEADED mode on port $Port..." -ForegroundColor Green

# Navigate to temp directory
$tempDir = Join-Path $env:TEMP "playwright-wsl-server"
if (!(Test-Path $tempDir)) {
    New-Item -ItemType Directory -Path $tempDir | Out-Null
}
Set-Location $tempDir

# Make sure Playwright is installed
if (!(Test-Path "node_modules\playwright")) {
    Write-Host "Installing Playwright..." -ForegroundColor Yellow
    npm init -y 2>$null
    npm install playwright
}

# Install browsers if needed
Write-Host "Ensuring browsers are installed..." -ForegroundColor Yellow
npx playwright install chromium
npx playwright install firefox

Write-Host "Starting HEADED Playwright server..." -ForegroundColor Cyan
Write-Host "Browser windows WILL be visible!" -ForegroundColor Yellow
Write-Host "" -ForegroundColor White

# Start server with environment variable to force headed mode
$env:PLAYWRIGHT_LAUNCH_OPTIONS = '{"headless":false}'
npx playwright run-server --port $Port