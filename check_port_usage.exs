# Check what's using port 3333
IO.puts("Checking what's using port 3333...")

ps_script = """
$port = 3333
Write-Host "Checking port $port usage..."

# Check for processes listening on the port
$listeners = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue
if ($listeners) {
    Write-Host "Found listeners on port $port:"
    foreach ($listener in $listeners) {
        $process = Get-Process -Id $listener.OwningProcess -ErrorAction SilentlyContinue
        if ($process) {
            Write-Host "  PID $($listener.OwningProcess): $($process.ProcessName) - $($process.CommandLine)"
        } else {
            Write-Host "  PID $($listener.OwningProcess): Process not found"
        }
    }
} else {
    Write-Host "No processes listening on port $port"
}

# Also check if we can connect to it
try {
    $tcpClient = New-Object System.Net.Sockets.TcpClient
    $tcpClient.Connect("localhost", $port)
    $tcpClient.Close()
    Write-Host "Port $port is accessible"
} catch {
    Write-Host "Port $port is not accessible: $($_.Exception.Message)"
}
"""

{output, exit_code} = System.cmd("powershell.exe", [
  "-ExecutionPolicy", "Bypass",
  "-Command", ps_script
])

IO.puts("Exit code: #{exit_code}")
IO.puts("Output:")
IO.puts(output)