# Test manual server startup with detailed logging
IO.puts("Testing manual server startup with detailed output...")

# The exact PowerShell script our adapter uses
ps_script = """
$ErrorActionPreference = 'Stop'

# Check if Node.js is installed
try {
    $nodeVersion = node --version
    Write-Host "Node.js version: $nodeVersion"
} catch {
    Write-Error 'Node.js is not installed on Windows. Please install from https://nodejs.org/'
    exit 1
}

# Check if port is already in use
$port = 3333
$tcpConnection = New-Object System.Net.Sockets.TcpClient
try {
    $tcpConnection.Connect('localhost', $port)
    $tcpConnection.Close()
    Write-Host "Port $port is already in use"
    exit 0
} catch {
    Write-Host "Port $port is free"
}

# Setup directory
$tempDir = Join-Path $env:TEMP 'playwright-wsl-server'
Write-Host "Using directory: $tempDir"
if (!(Test-Path $tempDir)) {
    New-Item -ItemType Directory -Path $tempDir | Out-Null
    Write-Host "Created directory: $tempDir"
}
Set-Location $tempDir

# Create package.json if needed
if (!(Test-Path 'package.json')) {
    Write-Host "Creating package.json..."
    @'
    {
      "name": "playwright-wsl-server",
      "version": "1.0.0",
      "dependencies": {
        "playwright": "latest"
      }
    }
    '@ | Out-File -FilePath 'package.json' -Encoding utf8
}

# Install Playwright if needed
if (!(Test-Path 'node_modules\\playwright')) {
    Write-Host 'Installing Playwright...'
    npm install --silent
}

# Install browsers
Write-Host 'Installing/checking browsers...'
npx playwright install chromium --force
npx playwright install firefox --force

# Start server in a visible window
Write-Host "Starting Playwright server on port $port..."
Write-Host "Server will start in a new window"

# Create a batch file to keep the server running
$batchContent = @"
@echo off
echo Starting Playwright server on port $port...
echo Directory: $tempDir
cd /d "$tempDir"
echo Running: npx playwright run-server --port $port
npx playwright run-server --port $port
echo Server stopped. Press any key to exit.
pause
"@

$batchFile = Join-Path $tempDir 'server.bat'
$batchContent | Out-File -FilePath $batchFile -Encoding ascii

Write-Host "Starting server in new window..."
Start-Process cmd -ArgumentList '/c', $batchFile -WindowStyle Normal

Write-Host "Server startup initiated"
"""

IO.puts("Executing PowerShell script...")

{output, exit_code} = System.cmd("powershell.exe", [
  "-ExecutionPolicy", "Bypass",
  "-Command", ps_script
])

IO.puts("Exit code: #{exit_code}")
IO.puts("Full output:")
IO.puts(output)

IO.puts("\nWaiting 10 seconds for server to start...")
Process.sleep(10_000)

# Now test connection
IO.puts("Testing connection to various endpoints...")

endpoints = [
  "ws://localhost:3333/",
  "ws://127.0.0.1:3333/",
  "ws://172.19.176.1:3333/"
]

Enum.each(endpoints, fn endpoint ->
  IO.write("Testing #{endpoint}... ")
  uri = URI.parse(endpoint)
  case :gen_tcp.connect(String.to_charlist(uri.host), uri.port, [:binary, active: false], 2000) do
    {:ok, socket} ->
      :gen_tcp.close(socket)
      IO.puts("✓ Connected!")
    {:error, reason} ->
      IO.puts("✗ Failed: #{inspect(reason)}")
  end
end)