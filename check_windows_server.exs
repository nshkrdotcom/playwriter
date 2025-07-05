# Check if Playwright server is running on Windows
IO.puts("Checking if Playwright server is running on Windows...\n")

# PowerShell script to check server status
ps_script = """
$port = 3333

# Check if any process is listening on the port
$listener = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue
if ($listener) {
    Write-Host "✓ Service is listening on port $port"
    Write-Host "Process ID: $($listener.OwningProcess)"
    
    # Get process details
    $process = Get-Process -Id $listener.OwningProcess -ErrorAction SilentlyContinue
    if ($process) {
        Write-Host "Process: $($process.ProcessName)"
        Write-Host "Command: $($process.CommandLine)"
    }
} else {
    Write-Host "✗ No service listening on port $port"
}

# Check for Playwright processes
$playwrightProcesses = Get-Process node -ErrorAction SilentlyContinue | Where-Object {$_.CommandLine -like "*playwright*run-server*"}
if ($playwrightProcesses) {
    Write-Host ""
    Write-Host "✓ Found Playwright server processes:"
    foreach ($proc in $playwrightProcesses) {
        Write-Host "  PID $($proc.Id): $($proc.CommandLine)"
    }
} else {
    Write-Host ""
    Write-Host "✗ No Playwright server processes found"
}

# Test localhost connection
Write-Host ""
Write-Host "Testing localhost connection:"
try {
    $tcpClient = New-Object System.Net.Sockets.TcpClient
    $tcpClient.Connect("localhost", $port)
    $tcpClient.Close()
    Write-Host "✓ Can connect to localhost:$port"
} catch {
    Write-Host "✗ Cannot connect to localhost:$port"
    Write-Host "Error: $($_.Exception.Message)"
}

# Get network interfaces
Write-Host ""
Write-Host "Network interfaces that WSL might use:"
Get-NetIPAddress | Where-Object {$_.AddressFamily -eq "IPv4" -and $_.IPAddress -ne "127.0.0.1"} | 
    ForEach-Object {
        Write-Host "  $($_.IPAddress) ($($_.InterfaceAlias))"
    }
"""

{output, exit_code} = System.cmd("powershell.exe", [
  "-ExecutionPolicy", "Bypass", 
  "-Command", ps_script
])

IO.puts("PowerShell exit code: #{exit_code}")
IO.puts("Output:")
IO.puts(output)

# Now check from WSL side if we can reach any of the Windows IPs
IO.puts("\n" <> String.duplicate("=", 50))
IO.puts("Testing from WSL side:")

# Try different ways to get Windows IP
potential_ips = [
  "127.0.0.1",
  "localhost"
]

# Get from resolv.conf
case System.cmd("cat", ["/etc/resolv.conf"]) do
  {resolv_output, 0} ->
    case Regex.run(~r/nameserver\s+(\d+\.\d+\.\d+\.\d+)/, resolv_output) do
      [_, ip] -> potential_ips = [ip | potential_ips]
      _ -> :ok
    end
  _ -> :ok
end

# Get from default gateway
case System.cmd("ip", ["route", "show", "default"]) do
  {route_output, 0} ->
    case Regex.run(~r/default via (\d+\.\d+\.\d+\.\d+)/, route_output) do
      [_, ip] -> potential_ips = [ip | potential_ips]
      _ -> :ok
    end
  _ -> :ok
end

IO.puts("Potential Windows IPs to test: #{inspect(potential_ips)}")

Enum.each(potential_ips, fn ip ->
  IO.write("Testing #{ip}:3333... ")
  case :gen_tcp.connect(String.to_charlist(ip), 3333, [:binary, active: false], 2000) do
    {:ok, socket} ->
      :gen_tcp.close(socket)
      IO.puts("✓ SUCCESS!")
    {:error, reason} ->
      IO.puts("✗ Failed: #{inspect(reason)}")
  end
end)