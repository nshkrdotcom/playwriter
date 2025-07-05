# Playwright Server Manager for Windows
# This script manages a single Playwright server instance

param(
    [string]$Action = "start",  # start, stop, status
    [int]$Port = 3333
)

$ErrorActionPreference = "Stop"

function Get-PlaywrightProcess {
    Get-Process node -ErrorAction SilentlyContinue | 
        Where-Object { $_.CommandLine -like "*playwright*run-server*" }
}

function Test-PortOpen {
    param([int]$Port)
    try {
        $connection = New-Object System.Net.Sockets.TcpClient
        $connection.Connect("localhost", $Port)
        $connection.Close()
        return $true
    } catch {
        return $false
    }
}

function Stop-PlaywrightServer {
    Write-Host "Stopping Playwright server..." -ForegroundColor Yellow
    $process = Get-PlaywrightProcess
    if ($process) {
        $process | Stop-Process -Force
        Write-Host "Playwright server stopped." -ForegroundColor Green
    } else {
        Write-Host "No Playwright server found running." -ForegroundColor Gray
    }
}

function Get-ServerStatus {
    $process = Get-PlaywrightProcess
    $portOpen = Test-PortOpen -Port $Port
    
    if ($process -and $portOpen) {
        Write-Host "Playwright server is RUNNING on port $Port" -ForegroundColor Green
        Write-Host "Process ID: $($process.Id)" -ForegroundColor Cyan
        return $true
    } elseif ($process) {
        Write-Host "Playwright process found but port $Port is not responding" -ForegroundColor Yellow
        return $false
    } elseif ($portOpen) {
        Write-Host "Port $Port is open but not by Playwright (another service?)" -ForegroundColor Yellow
        return $false
    } else {
        Write-Host "Playwright server is NOT running" -ForegroundColor Red
        return $false
    }
}

function Start-PlaywrightServer {
    Write-Host "Starting Playwright server on port $Port..." -ForegroundColor Yellow
    
    # Check if already running
    if (Get-ServerStatus) {
        Write-Host "Server is already running!" -ForegroundColor Green
        return
    }
    
    # Check if port is in use by something else
    if (Test-PortOpen -Port $Port) {
        Write-Host "Port $Port is already in use by another process!" -ForegroundColor Red
        Write-Host "Try using a different port or stop the other process." -ForegroundColor Yellow
        exit 1
    }
    
    # Setup directory
    $tempDir = Join-Path $env:TEMP "playwright-wsl-server"
    if (!(Test-Path $tempDir)) {
        New-Item -ItemType Directory -Path $tempDir | Out-Null
    }
    Set-Location $tempDir
    
    # Create package.json if needed
    if (!(Test-Path "package.json")) {
        @{
            name = "playwright-wsl-server"
            version = "1.0.0"
            dependencies = @{
                playwright = "latest"
            }
        } | ConvertTo-Json | Out-File -FilePath "package.json" -Encoding utf8
    }
    
    # Install Playwright if needed
    if (!(Test-Path "node_modules\playwright")) {
        Write-Host "Installing Playwright..." -ForegroundColor Yellow
        npm install
    }
    
    # Install browsers
    Write-Host "Ensuring browsers are installed..." -ForegroundColor Yellow
    npx playwright install chromium
    npx playwright install firefox
    
    # Start server in background
    Write-Host "Starting server in background..." -ForegroundColor Yellow
    
    $serverProcess = Start-Process powershell -ArgumentList @(
        "-WindowStyle", "Hidden",
        "-Command", "cd '$tempDir'; npx playwright run-server --port $Port"
    ) -PassThru
    
    # Wait for server to start
    $timeout = 10
    $started = $false
    for ($i = 0; $i -lt $timeout; $i++) {
        Start-Sleep -Seconds 1
        if (Test-PortOpen -Port $Port) {
            $started = $true
            break
        }
    }
    
    if ($started) {
        Write-Host "Playwright server started successfully!" -ForegroundColor Green
        Write-Host "" -ForegroundColor White
        Write-Host "Connection endpoints:" -ForegroundColor Cyan
        Write-Host "  ws://localhost:$Port/" -ForegroundColor Green
        Write-Host "  ws://127.0.0.1:$Port/" -ForegroundColor Green
        
        # Get WSL-accessible IP
        $wslIP = Get-NetIPAddress | 
            Where-Object {$_.InterfaceAlias -like "*WSL*" -and $_.AddressFamily -eq "IPv4"} | 
            Select-Object -First 1 -ExpandProperty IPAddress
        if ($wslIP) {
            Write-Host "  ws://${wslIP}:$Port/ (WSL interface)" -ForegroundColor Yellow
        }
        
        Write-Host "" -ForegroundColor White
        Write-Host "Server is running in the background (PID: $($serverProcess.Id))" -ForegroundColor Gray
        Write-Host "To stop: .\playwright_server_manager.ps1 -Action stop" -ForegroundColor Gray
    } else {
        Write-Host "Failed to start server!" -ForegroundColor Red
        if ($serverProcess) {
            $serverProcess | Stop-Process -Force
        }
        exit 1
    }
}

# Main execution
switch ($Action.ToLower()) {
    "start" {
        Start-PlaywrightServer
    }
    "stop" {
        Stop-PlaywrightServer
    }
    "status" {
        Get-ServerStatus | Out-Null
    }
    "restart" {
        Stop-PlaywrightServer
        Start-Sleep -Seconds 2
        Start-PlaywrightServer
    }
    default {
        Write-Host "Usage: .\playwright_server_manager.ps1 -Action [start|stop|status|restart] [-Port 3333]" -ForegroundColor Yellow
    }
}