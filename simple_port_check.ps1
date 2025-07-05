# Simple check for what's on port 3333
Write-Host "Checking port 3333..."

# Get processes using port 3333
$connections = Get-NetTCPConnection -LocalPort 3333 -ErrorAction SilentlyContinue
if ($connections) {
    foreach ($conn in $connections) {
        Write-Host "PID: $($conn.OwningProcess)"
        $process = Get-Process -Id $conn.OwningProcess -ErrorAction SilentlyContinue
        if ($process) {
            Write-Host "Process: $($process.ProcessName)"
            Write-Host "Command: $($process.CommandLine)"
        }
    }
} else {
    Write-Host "No process found on port 3333"
}

# List all node processes
Write-Host "`nAll Node.js processes:"
Get-Process node -ErrorAction SilentlyContinue | ForEach-Object {
    Write-Host "PID $($_.Id): $($_.CommandLine)"
}