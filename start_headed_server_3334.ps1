# Start a HEADED Playwright server on port 3334
Write-Host "Starting HEADED Playwright server on port 3334..." -ForegroundColor Green
Write-Host "This will open VISIBLE browser windows!" -ForegroundColor Yellow

# Navigate to temp directory
cd $env:TEMP

# Check if Playwright is installed
if (!(Test-Path "node_modules\playwright")) {
    Write-Host "Installing Playwright..." -ForegroundColor Yellow
    npm init -y
    npm install playwright
}

# Install browsers
Write-Host "Installing browsers..." -ForegroundColor Yellow
npx playwright install chromium
npx playwright install firefox

Write-Host ""
Write-Host "Starting HEADED server (browsers will be VISIBLE)..." -ForegroundColor Cyan
Write-Host "Press Ctrl+C to stop" -ForegroundColor Gray
Write-Host ""

# Start server with browsers in headed mode (no --headless flag)
npx playwright run-server --port 3334