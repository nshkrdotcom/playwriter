# Kill any existing Playwright processes
Write-Host "Stopping any existing Playwright processes..."

# Find and stop Node.js processes that are running Playwright
$playwrightProcesses = Get-Process node -ErrorAction SilentlyContinue | Where-Object {
    $_.CommandLine -like "*playwright*run-server*"
}

if ($playwrightProcesses) {
    Write-Host "Found $($playwrightProcesses.Count) Playwright server process(es)"
    foreach ($proc in $playwrightProcesses) {
        Write-Host "Stopping PID $($proc.Id)..."
        Stop-Process -Id $proc.Id -Force
    }
    Write-Host "All Playwright servers stopped"
} else {
    Write-Host "No Playwright server processes found"
}

Write-Host "Done"