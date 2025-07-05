$connections = Get-NetTCPConnection -LocalPort 3333 -ErrorAction SilentlyContinue
foreach ($conn in $connections) {
    $process = Get-Process -Id $conn.OwningProcess -ErrorAction SilentlyContinue
    if ($process) {
        Write-Host "Killing process $($process.Id) using port 3333"
        Stop-Process -Id $process.Id -Force
    }
}