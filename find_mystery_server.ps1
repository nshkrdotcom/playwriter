# Find what's actually running on port 3333
Write-Host "=== Investigating Mystery Server on Port 3333 ===" -ForegroundColor Yellow
Write-Host ""

# Check what's listening on port 3333
Write-Host "1. Checking what's listening on port 3333..." -ForegroundColor Cyan
try {
    $connections = Get-NetTCPConnection -LocalPort 3333 -ErrorAction SilentlyContinue
    if ($connections) {
        foreach ($conn in $connections) {
            Write-Host "  Found connection:" -ForegroundColor Green
            Write-Host "    Local: $($conn.LocalAddress):$($conn.LocalPort)"
            Write-Host "    Remote: $($conn.RemoteAddress):$($conn.RemotePort)"
            Write-Host "    State: $($conn.State)"
            Write-Host "    PID: $($conn.OwningProcess)"
            
            # Get process details
            try {
                $process = Get-Process -Id $conn.OwningProcess -ErrorAction SilentlyContinue
                if ($process) {
                    Write-Host "    Process: $($process.ProcessName)"
                    Write-Host "    Command: $($process.CommandLine)"
                    Write-Host "    Started: $($process.StartTime)"
                }
            } catch {
                Write-Host "    Process details not available"
            }
            Write-Host ""
        }
    } else {
        Write-Host "  No connections found on port 3333" -ForegroundColor Red
    }
} catch {
    Write-Host "  Error checking connections: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "2. Looking for Node.js processes..." -ForegroundColor Cyan
$nodeProcesses = Get-Process node -ErrorAction SilentlyContinue
if ($nodeProcesses) {
    foreach ($proc in $nodeProcesses) {
        Write-Host "  PID $($proc.Id): $($proc.ProcessName)"
        if ($proc.CommandLine) {
            Write-Host "    Command: $($proc.CommandLine)"
        }
        Write-Host "    Started: $($proc.StartTime)"
        Write-Host ""
    }
} else {
    Write-Host "  No Node.js processes found" -ForegroundColor Gray
}

Write-Host "3. Looking for Playwright-related processes..." -ForegroundColor Cyan
$allProcesses = Get-Process -ErrorAction SilentlyContinue | Where-Object {
    $_.CommandLine -like "*playwright*" -or 
    $_.CommandLine -like "*run-server*" -or
    $_.ProcessName -like "*chrome*" -or
    $_.ProcessName -like "*chromium*"
}

if ($allProcesses) {
    foreach ($proc in $allProcesses) {
        Write-Host "  PID $($proc.Id): $($proc.ProcessName)"
        if ($proc.CommandLine) {
            Write-Host "    Command: $($proc.CommandLine)"
        }
        Write-Host ""
    }
} else {
    Write-Host "  No Playwright-related processes found" -ForegroundColor Gray
}

Write-Host "4. Testing if we can connect to port 3333..." -ForegroundColor Cyan
try {
    $tcpClient = New-Object System.Net.Sockets.TcpClient
    $tcpClient.Connect("localhost", 3333)
    $tcpClient.Close()
    Write-Host "  ✓ Can connect to localhost:3333" -ForegroundColor Green
} catch {
    Write-Host "  ✗ Cannot connect to localhost:3333: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Investigation Complete ===" -ForegroundColor Yellow