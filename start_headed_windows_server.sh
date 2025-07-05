#!/bin/bash

echo "Starting HEADED Playwright server on Windows..."
echo "This will open VISIBLE browser windows when you use the system!"
echo

# Kill any existing servers
echo "Cleaning up any existing servers..."
powershell.exe -ExecutionPolicy Bypass -File ./kill_playwright.ps1

echo "Starting headed server on port 3336..."

# Start the server using PowerShell script
powershell.exe -ExecutionPolicy Bypass -File ./start_headed.ps1