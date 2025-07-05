# Kill the headless Playwright server
Write-Host "Stopping headless Playwright server..."

# Find and stop the specific process
$playwrightProcesses = Get-Process node -ErrorAction SilentlyContinue | Where-Object {
    $_.CommandLine -like "*playwright*run-server*"
}

if ($playwrightProcesses) {
    foreach ($proc in $playwrightProcesses) {
        Write-Host "Stopping PID $($proc.Id)..."
        Stop-Process -Id $proc.Id -Force
    }
    Write-Host "Headless server stopped"
} else {
    Write-Host "No Playwright server found"
}

# Also kill the WSL PowerShell process if it exists
$powershellProcesses = Get-Process powershell -ErrorAction SilentlyContinue | Where-Object {
    $_.CommandLine -like "*playwright*"
}

if ($powershellProcesses) {
    foreach ($proc in $powershellProcesses) {
        Write-Host "Stopping PowerShell PID $($proc.Id)..."
        Stop-Process -Id $proc.Id -Force
    }
}

Write-Host "Done"