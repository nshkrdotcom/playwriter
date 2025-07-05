$chromiumPath = "$env:LOCALAPPDATA\ms-playwright\chromium-1179\chrome-win\chrome.exe"
$profilePath = "$env:TEMP\playwriter-chromium-profile"

Write-Host "Starting Playwright Chromium with profile directory..."
Write-Host "Chromium path: $chromiumPath"
Write-Host "Profile path: $profilePath"

if (Test-Path $chromiumPath) {
    & $chromiumPath --user-data-dir=$profilePath
} else {
    Write-Host "Chromium not found at $chromiumPath"
}