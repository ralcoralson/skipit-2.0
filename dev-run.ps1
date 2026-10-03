# SkipIt Dynamic Development Launcher
# This script automatically detects your environment configurations, resolves dynamic IP addresses/tunnels,
# updates your mobile app's API Base URL automatically, and launches both backend and mobile clients.

Clear-Host
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "     SKIPIT 2.0 DEV LAUNCHER & ROUTER" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Detect Network configuration
Write-Host "[1/3] Detecting local host IP address..." -ForegroundColor Yellow
$WiFiIP = (Get-NetIPAddress -InterfaceAlias "Wi-Fi" -AddressFamily IPv4 -ErrorAction SilentlyContinue).IPAddress
if (-not $WiFiIP) {
    $WiFiIP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -ne "127.0.0.1" -and $_.IPAddress -notlike "169.254.*" } | Select-Object -First 1).IPAddress
}

if (-not $WiFiIP) {
    Write-Host "[-] Warning: No active local network adapter detected. Defaulting to localhost." -ForegroundColor Red
    $WiFiIP = "10.0.2.2" # Android emulator loopback fallback
} else {
    Write-Host "[+] Detected Wi-Fi IP address: $WiFiIP" -ForegroundColor Green
}

# 2. Ask user for connection choice to support both local and remote testing
Write-Host ""
Write-Host "Choose how your mobile device will connect to the NestJS backend:" -ForegroundColor Cyan
Write-Host "1) Local Wi-Fi Connection (Recommended: Blazing Fast, Stable, Permanent)" -ForegroundColor White
Write-Host "2) Active localhost.run SSH Tunnel (For Remote / Mobile Hotspot Testing)" -ForegroundColor White
$choice = Read-Host "Enter your choice (1 or 2, default is 1)"

$TargetApiUrl = ""
if ($choice -eq "2") {
    Write-Host ""
    Write-Host "[2/3] Checking active SSH tunnel URL..." -ForegroundColor Yellow
    
    # Prompt for URL or auto-detect if possible
    $inputUrl = Read-Host "Enter your active localhost.run https URL (e.g. https://xxxx.lhr.life)"
    if ($inputUrl -match "^https?://") {
        $TargetApiUrl = $inputUrl.TrimEnd('/') + "/api"
    } else {
        Write-Host "[-] Invalid URL format. Defaulting to Wi-Fi IP." -ForegroundColor Red
        $TargetApiUrl = "http://$WiFiIP:3000/api"
    }
} else {
    $TargetApiUrl = "http://$WiFiIP:3000/api"
}

Write-Host ""
Write-Host "[3/3] Synchronizing mobile configuration file..." -ForegroundColor Yellow
$ConfigPath = "apps/mobile/lib/core/config/app_config.dart"

if (Test-Path $ConfigPath) {
    $Content = Get-Content $ConfigPath -Raw
    # Regex to cleanly replace defaultValue for API_BASE_URL
    $NewContent = $Content -replace "defaultValue:\s*'https?://[^']+/api'", "defaultValue: '$TargetApiUrl'"
    Set-Content -Path $ConfigPath -Value $NewContent -NoNewline
    Write-Host "[+] Successfully synced apps/mobile/lib/core/config/app_config.dart to: $TargetApiUrl" -ForegroundColor Green
} else {
    Write-Host "[-] Error: Could not locate app_config.dart at $ConfigPath" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Green
Write-Host "   CONFIG SYNCED. LAUNCHING SKIPIT..." -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""

# Ask to run the app
$RunChoice = Read-Host "Do you want to launch the Flutter app on the mobile device now? (Y/n)"
if ($RunChoice -ne "n" -and $RunChoice -ne "N") {
    Write-Host "[+] Starting Flutter run..." -ForegroundColor Green
    cd apps/mobile
    flutter run -d 12431314C8123137
} else {
    Write-Host "[+] Done! You can now manually run your Flutter command or build task." -ForegroundColor Yellow
}
