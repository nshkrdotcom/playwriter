Write-Host "Starting HEADED Playwright server on port 3336..." -ForegroundColor Green
Write-Host "Browsers will be VISIBLE when used!" -ForegroundColor Yellow

cd $env:TEMP
$env:PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS = '1'

Write-Host "Starting server in background..." -ForegroundColor Cyan
# Start server with launch options that force headed mode
Start-Process powershell -ArgumentList '-NoExit', '-Command', 'cd $env:TEMP; $env:PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS = "1"; npx playwright run-server --port 3336 --browser=chromium --launch-options="{\"headless\":false}"' -WindowStyle Minimized