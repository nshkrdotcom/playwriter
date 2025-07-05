Get-Process node -ErrorAction SilentlyContinue | Where-Object {$_.CommandLine -like '*playwright*'} | Stop-Process -Force
Write-Host "Killed any orphaned Playwright processes"