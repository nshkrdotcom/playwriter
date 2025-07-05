$chromePath = "$env:LOCALAPPDATA\Google\Chrome\User Data"
Write-Host "Chrome data directory: $chromePath"

if (Test-Path $chromePath) {
    $profiles = Get-ChildItem $chromePath -Directory | Where-Object {$_.Name -match '^(Default|Profile )' -or $_.Name -eq 'Profile 1'}
    
    if ($profiles) {
        Write-Host "Available Chrome profiles:"
        foreach ($profile in $profiles) {
            Write-Host "  - $($profile.Name) ($($profile.FullName))"
        }
    } else {
        Write-Host "No Chrome profiles found."
    }
} else {
    Write-Host "Chrome user data directory not found."
}