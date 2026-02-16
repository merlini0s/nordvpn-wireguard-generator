<#
.SYNOPSIS
    NordVPN WireGuard Configuration Generator for Router Setup

.DESCRIPTION
    This script generates WireGuard configuration files for NordVPN (NordLynx)
    that can be used on routers and other devices that support WireGuard.
    
    Features:
    - Select country first
    - View all servers with load metrics
    - Choose specific servers or auto-select best ones

.PARAMETER Token
    Your NordVPN access token. If not provided, you'll be prompted to enter it.

.EXAMPLE
    .\NordVPN-WireGuard-Generator.ps1
    
.NOTES
    Author: GitHub Community
    Requires: Windows PowerShell 5.1+ or PowerShell Core 7+
#>

param(
    [string]$Token
)

# Ensure TLS 1.2 for API calls
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

#region Functions

function Write-Banner {
    $banner = @"

 _   _               ___     ______  _   _ 
| \ | | ___  _ __ __| \ \   / /  _ \| \ | |
|  \| |/ _ \| '__/ _` |\ \ / /| |_) |  \| |
| |\  | (_) | | | (_| | \ V / |  __/| |\  |
|_| \_|\___/|_|  \__,_|  \_/  |_|   |_| \_|
                                            
    WireGuard Configuration Generator
    
"@
    Write-Host $banner -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor DarkGray
    Write-Host ""
}

function Get-NordVPNPrivateKey {
    param([string]$AccessToken)
    
    try {
        $credentials = "token:$AccessToken"
        $encodedCredentials = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($credentials))
        $headers = @{ "Authorization" = "Basic $encodedCredentials" }
        
        $response = Invoke-RestMethod -Uri "https://api.nordvpn.com/v1/users/services/credentials" `
            -Headers $headers -Method Get -ErrorAction Stop
        
        return $response.nordlynx_private_key
    }
    catch {
        if ($_.Exception.Response.StatusCode -eq 401) {
            Write-Host "[ERROR] Invalid or expired access token." -ForegroundColor Red
        }
        else {
            Write-Host "[ERROR] Failed to retrieve private key: $($_.Exception.Message)" -ForegroundColor Red
        }
        return $null
    }
}

function Get-NordVPNCountries {
    try {
        $countries = Invoke-RestMethod -Uri "https://api.nordvpn.com/v1/servers/countries" `
            -Method Get -ErrorAction Stop
        return $countries | Sort-Object name
    }
    catch {
        Write-Host "[ERROR] Could not fetch country list: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

function Get-NordVPNServers {
    param(
        [int]$CountryId,
        [int]$Limit = 100
    )
    
    $baseUrl = "https://api.nordvpn.com/v1/servers/recommendations"
    $params = "filters[servers_technologies][identifier]=wireguard_udp&filters[country_id]=$CountryId&limit=$Limit"
    
    $url = "$baseUrl`?$params"
    
    try {
        $servers = Invoke-RestMethod -Uri $url -Method Get -ErrorAction Stop
        return $servers
    }
    catch {
        Write-Host "[ERROR] Failed to fetch servers: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

function Show-ServerList {
    param(
        [array]$Servers,
        [string]$CountryName
    )
    
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host " Available WireGuard Servers in $CountryName" -ForegroundColor Cyan
    Write-Host " Sorted by load (lowest = best performance)" -ForegroundColor Gray
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
    
    # Create header
    $header = "{0,-4} {1,-30} {2,-20} {3,-8} {4,-15}" -f "#", "HOSTNAME", "CITY", "LOAD", "IP ADDRESS"
    Write-Host $header -ForegroundColor Yellow
    Write-Host ("-" * 80) -ForegroundColor DarkGray
    
    # Display servers
    $index = 1
    foreach ($server in $Servers) {
        $hostname = $server.hostname
        $city = $server.locations[0].country.city.name
        $load = "$($server.load)%"
        $ip = $server.station
        
        # Color code based on load
        $loadValue = $server.load
        $color = if ($loadValue -le 30) { "Green" } 
                 elseif ($loadValue -le 60) { "Yellow" } 
                 else { "Red" }
        
        $line = "{0,-4} {1,-30} {2,-20} " -f $index, $hostname, $city
        Write-Host $line -NoNewline
        Write-Host ("{0,-8} " -f $load) -NoNewline -ForegroundColor $color
        Write-Host ("{0,-15}" -f $ip) -ForegroundColor Gray
        
        $index++
    }
    
    Write-Host ""
    Write-Host "Load Legend: " -NoNewline
    Write-Host "GREEN = Low (0-30%)" -ForegroundColor Green -NoNewline
    Write-Host " | " -NoNewline
    Write-Host "YELLOW = Medium (31-60%)" -ForegroundColor Yellow -NoNewline
    Write-Host " | " -NoNewline
    Write-Host "RED = High (61%+)" -ForegroundColor Red
    Write-Host ""
}

function New-WireGuardConfig {
    param(
        [string]$PrivateKey,
        [object]$Server,
        [string]$DNS
    )
    
    $hostname = $Server.hostname
    $serverIP = $Server.station
    $load = $Server.load
    $city = $Server.locations[0].country.city.name
    $country = $Server.locations[0].country.name
    
    # Extract public key from server technologies
    $publicKey = ""
    foreach ($tech in $Server.technologies) {
        if ($tech.identifier -eq "wireguard_udp") {
            foreach ($meta in $tech.metadata) {
                if ($meta.name -eq "public_key") {
                    $publicKey = $meta.value
                    break
                }
            }
        }
    }
    
    $config = @"
# ============================================
# NordVPN WireGuard Configuration
# ============================================
# Server   : $hostname
# Location : $city, $country
# Load     : $load%
# IP       : $serverIP
# Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
# ============================================

[Interface]
PrivateKey = $PrivateKey
Address = 10.5.0.2/32
DNS = $DNS

[Peer]
PublicKey = $publicKey
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = $serverIP`:51820
PersistentKeepalive = 25
"@
    
    return @{
        Config    = $config
        Hostname  = $hostname
        City      = $city
        Country   = $country
        Load      = $load
        ServerIP  = $serverIP
        PublicKey = $publicKey
    }
}

function Show-CountrySelection {
    param([array]$Countries)
    
    Write-Host ""
    Write-Host "Popular countries:" -ForegroundColor Yellow
    Write-Host ""
    
    $popular = @(
        @{Code = "US"; Name = "United States" },
        @{Code = "GB"; Name = "United Kingdom" },
        @{Code = "DE"; Name = "Germany" },
        @{Code = "NL"; Name = "Netherlands" },
        @{Code = "CA"; Name = "Canada" },
        @{Code = "FR"; Name = "France" },
        @{Code = "CH"; Name = "Switzerland" },
        @{Code = "SE"; Name = "Sweden" },
        @{Code = "JP"; Name = "Japan" },
        @{Code = "AU"; Name = "Australia" },
        @{Code = "GR"; Name = "Greece" },
        @{Code = "IT"; Name = "Italy" },
        @{Code = "ES"; Name = "Spain" },
        @{Code = "PL"; Name = "Poland" },
        @{Code = "AT"; Name = "Austria" }
    )
    
    # Display in 3 columns
    for ($i = 0; $i -lt $popular.Count; $i += 3) {
        $col1 = if ($i -lt $popular.Count) { "{0,2}. {1,-18} [{2}]" -f ($i + 1), $popular[$i].Name, $popular[$i].Code } else { "" }
        $col2 = if (($i + 1) -lt $popular.Count) { "{0,2}. {1,-18} [{2}]" -f ($i + 2), $popular[$i + 1].Name, $popular[$i + 1].Code } else { "" }
        $col3 = if (($i + 2) -lt $popular.Count) { "{0,2}. {1,-18} [{2}]" -f ($i + 3), $popular[$i + 2].Name, $popular[$i + 2].Code } else { "" }
        
        Write-Host "  $col1  $col2  $col3"
    }
    
    Write-Host ""
    Write-Host "  Enter a number (1-$($popular.Count)) or any country code (e.g., US, GR, NL)" -ForegroundColor Gray
    
    return $popular
}

#endregion Functions

#region Main Script

Write-Banner

# ==================== STEP 1: Access Token ====================
Write-Host "[STEP 1] NordVPN Access Token" -ForegroundColor Green
Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray

if (-not $Token) {
    Write-Host ""
    Write-Host "To obtain your access token:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  1. Visit: " -NoNewline
    Write-Host "https://my.nordaccount.com/dashboard/nordvpn/manual-configuration/" -ForegroundColor Cyan
    Write-Host "  2. Click 'Set up NordVPN Manually' (re-authenticate if needed)"
    Write-Host "  3. Generate a new token with 'Get service credentials' permission"
    Write-Host ""
    
    $Token = Read-Host "Enter your NordVPN access token"
}

if ([string]::IsNullOrWhiteSpace($Token)) {
    Write-Host "[ERROR] Access token is required. Exiting." -ForegroundColor Red
    exit 1
}

# ==================== STEP 2: Private Key ====================
Write-Host ""
Write-Host "[STEP 2] Retrieving Your WireGuard Private Key" -ForegroundColor Green
Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host ""
Write-Host "Connecting to NordVPN API..." -ForegroundColor Gray

$privateKey = Get-NordVPNPrivateKey -AccessToken $Token

if (-not $privateKey) {
    Write-Host ""
    Write-Host "Failed to retrieve private key. Please verify your access token." -ForegroundColor Red
    exit 1
}

Write-Host "[OK] Private key retrieved successfully!" -ForegroundColor Green

# ==================== STEP 3: Country Selection ====================
Write-Host ""
Write-Host "[STEP 3] Select Country" -ForegroundColor Green
Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray

$countries = Get-NordVPNCountries

if (-not $countries) {
    Write-Host "Failed to fetch countries. Exiting." -ForegroundColor Red
    exit 1
}

$popularCountries = Show-CountrySelection -Countries $countries
Write-Host ""
$countryInput = Read-Host "Select country"

$selectedCountry = $null

if ($countryInput -match '^\d+$') {
    $num = [int]$countryInput
    if ($num -ge 1 -and $num -le $popularCountries.Count) {
        $code = $popularCountries[$num - 1].Code
        $selectedCountry = $countries | Where-Object { $_.code -eq $code }
    }
}
else {
    $selectedCountry = $countries | Where-Object { $_.code -eq $countryInput.ToUpper() }
}

if (-not $selectedCountry) {
    Write-Host "[ERROR] Invalid country selection. Exiting." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "[OK] Selected: $($selectedCountry.name)" -ForegroundColor Cyan

# ==================== STEP 4: Fetch & Display Servers ====================
Write-Host ""
Write-Host "[STEP 4] Fetching Available Servers" -ForegroundColor Green
Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host ""
Write-Host "Fetching WireGuard servers from $($selectedCountry.name)..." -ForegroundColor Gray

$servers = Get-NordVPNServers -CountryId $selectedCountry.id -Limit 50

if (-not $servers -or $servers.Count -eq 0) {
    Write-Host "[ERROR] No WireGuard servers found in $($selectedCountry.name)." -ForegroundColor Red
    exit 1
}

# Sort by load (lowest first)
$servers = $servers | Sort-Object load

Write-Host "[OK] Found $($servers.Count) servers" -ForegroundColor Green

# Display server list
Show-ServerList -Servers $servers -CountryName $selectedCountry.name

# ==================== STEP 5: Server Selection ====================
Write-Host "[STEP 5] Select Servers" -ForegroundColor Green
Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host ""
Write-Host "Options:" -ForegroundColor Yellow
Write-Host "  - Enter server numbers separated by commas (e.g., 1,3,5)"
Write-Host "  - Enter 'best N' to auto-select top N lowest-load servers (e.g., best 3)"
Write-Host "  - Enter 'all' to generate configs for all servers"
Write-Host "  - Press Enter for top 3 best servers"
Write-Host ""

$selection = Read-Host "Your selection [best 3]"

$selectedServers = @()

if ([string]::IsNullOrWhiteSpace($selection) -or $selection -eq "best 3") {
    # Default: top 3 best servers
    $selectedServers = $servers | Select-Object -First 3
    Write-Host ""
    Write-Host "[OK] Selected top 3 servers with lowest load" -ForegroundColor Cyan
}
elseif ($selection -match '^best\s*(\d+)$') {
    $count = [int]$Matches[1]
    $count = [Math]::Min($count, $servers.Count)
    $selectedServers = $servers | Select-Object -First $count
    Write-Host ""
    Write-Host "[OK] Selected top $count servers with lowest load" -ForegroundColor Cyan
}
elseif ($selection -eq "all") {
    $selectedServers = $servers
    Write-Host ""
    Write-Host "[OK] Selected all $($servers.Count) servers" -ForegroundColor Cyan
}
else {
    # Parse comma-separated numbers
    $indices = $selection -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ }
    
    foreach ($idx in $indices) {
        if ($idx -ge 1 -and $idx -le $servers.Count) {
            $selectedServers += $servers[$idx - 1]
        }
    }
    
    if ($selectedServers.Count -eq 0) {
        Write-Host "[ERROR] No valid servers selected. Exiting." -ForegroundColor Red
        exit 1
    }
    
    Write-Host ""
    Write-Host "[OK] Selected $($selectedServers.Count) server(s)" -ForegroundColor Cyan
}

# ==================== STEP 6: DNS Selection ====================
Write-Host ""
Write-Host "[STEP 6] Select DNS Servers" -ForegroundColor Green
Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  1. NordVPN DNS      (103.86.96.100, 103.86.99.100) - Recommended"
Write-Host "  2. Cloudflare DNS   (1.1.1.1, 1.0.0.1) - Fast & Private"
Write-Host "  3. Google DNS       (8.8.8.8, 8.8.4.4) - Reliable"
Write-Host "  4. Quad9 DNS        (9.9.9.9, 149.112.112.112) - Security-focused"
Write-Host "  5. Custom"
Write-Host ""

$dnsChoice = Read-Host "Your choice [1]"
$dns = switch ($dnsChoice) {
    "2" { "1.1.1.1, 1.0.0.1" }
    "3" { "8.8.8.8, 8.8.4.4" }
    "4" { "9.9.9.9, 149.112.112.112" }
    "5" { 
        $customDns = Read-Host "Enter DNS servers (comma-separated)"
        if ($customDns) { $customDns } else { "103.86.96.100, 103.86.99.100" }
    }
    default { "103.86.96.100, 103.86.99.100" }
}

Write-Host ""
Write-Host "[OK] DNS: $dns" -ForegroundColor Cyan

# ==================== STEP 7: Generate Configurations ====================
Write-Host ""
Write-Host "[STEP 7] Generating Configuration Files" -ForegroundColor Green
Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host ""

# Create output directory
$outputDir = Join-Path -Path $PWD -ChildPath "NordVPN-WireGuard-Configs"
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$generatedFiles = @()

foreach ($server in $selectedServers) {
    $result = New-WireGuardConfig -PrivateKey $privateKey -Server $server -DNS $dns
    
    # Create safe filename
    $safeName = "$($result.Country)-$($result.City)-$($result.Hostname)" `
        -replace '\s+', '_' `
        -replace '[^\w\.\-]', ''
    $fileName = "$safeName.conf"
    $filePath = Join-Path -Path $outputDir -ChildPath $fileName
    
    # Save configuration file
    $result.Config | Out-File -FilePath $filePath -Encoding UTF8 -Force
    
    $generatedFiles += @{
        FileName = $fileName
        Hostname = $result.Hostname
        City     = $result.City
        Country  = $result.Country
        Load     = $result.Load
    }
    
    Write-Host "  [+] " -ForegroundColor Green -NoNewline
    Write-Host "$fileName " -NoNewline
    Write-Host "(Load: $($result.Load)%)" -ForegroundColor Gray
}

# ==================== Summary ====================
Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "             CONFIGURATION GENERATION COMPLETE!             " -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Output Directory:" -ForegroundColor Yellow
Write-Host "  $outputDir" -ForegroundColor Cyan
Write-Host ""
Write-Host "Generated $($generatedFiles.Count) configuration file(s):" -ForegroundColor Yellow

foreach ($file in $generatedFiles) {
    Write-Host "  - $($file.FileName) (Load: $($file.Load)%)" -ForegroundColor White
}

Write-Host ""
Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host " ROUTER CONFIGURATION REFERENCE" -ForegroundColor Yellow
Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host "  Interface Address  : 10.5.0.2/32" -ForegroundColor White
Write-Host "  Endpoint Port      : 51820" -ForegroundColor White
Write-Host "  DNS Servers        : $dns" -ForegroundColor White
Write-Host "  Allowed IPs        : 0.0.0.0/0, ::/0" -ForegroundColor White
Write-Host "  Keepalive          : 25 seconds" -ForegroundColor White
Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host ""
Write-Host "[!] SECURITY: Keep your .conf files private!" -ForegroundColor Yellow
Write-Host ""

# Offer to open folder
$openFolder = Read-Host "Open the output folder in Explorer? (Y/n)"
if ($openFolder -ne "n" -and $openFolder -ne "N") {
    Start-Process explorer.exe -ArgumentList $outputDir
}

Write-Host ""
Write-Host "Done! Import the .conf file(s) into your router's WireGuard client." -ForegroundColor Green
Write-Host ""

#endregion Main Script
