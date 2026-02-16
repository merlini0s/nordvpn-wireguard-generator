<#
.SYNOPSIS
    NordVPN WireGuard Configuration Generator for Router Setup

.DESCRIPTION
    This script generates WireGuard configuration files for NordVPN (NordLynx)
    that can be used on routers and other devices that support WireGuard.
    
    NordVPN doesn't officially provide WireGuard config files, but their
    NordLynx protocol is built on WireGuard. This script uses NordVPN's API
    to generate compatible configuration files.

.PARAMETER Token
    Your NordVPN access token. If not provided, you'll be prompted to enter it.

.PARAMETER Country
    Country code (e.g., US, GB, DE, NL) for server selection.
    If not provided, you can select interactively or use auto-recommended servers.

.PARAMETER ServerCount
    Number of server configurations to generate. Default is 3.

.EXAMPLE
    .\NordVPN-WireGuard-Generator.ps1
    
.EXAMPLE
    .\NordVPN-WireGuard-Generator.ps1 -Token "your_token_here" -Country "US" -ServerCount 5

.NOTES
    Author: GitHub Community
    Requires: Windows PowerShell 5.1+ or PowerShell Core 7+
    
.LINK
    https://my.nordaccount.com/dashboard/nordvpn/manual-configuration/
#>

param(
    [string]$Token,
    [string]$Country,
    [int]$ServerCount = 3
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
            Write-Host "        Please generate a new token from NordVPN dashboard." -ForegroundColor Gray
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
        return $countries
    }
    catch {
        Write-Host "[WARNING] Could not fetch country list." -ForegroundColor Yellow
        return $null
    }
}

function Get-NordVPNServers {
    param(
        [string]$CountryId,
        [int]$Limit
    )
    
    $baseUrl = "https://api.nordvpn.com/v1/servers/recommendations"
    $params = "filters[servers_technologies][identifier]=wireguard_udp&limit=$Limit"
    
    if ($CountryId) {
        $params += "&filters[country_id]=$CountryId"
    }
    
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
# Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss UTC" -AsUTC)
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

function Show-CountryMenu {
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
        @{Code = "AU"; Name = "Australia" }
    )
    
    for ($i = 0; $i -lt $popular.Count; $i++) {
        $countryData = $Countries | Where-Object { $_.code -eq $popular[$i].Code }
        $serverCount = if ($countryData) { " ($($countryData.id) servers)" } else { "" }
        Write-Host "  $($i + 1). $($popular[$i].Name) [$($popular[$i].Code)]" -ForegroundColor White
    }
    
    Write-Host ""
    Write-Host "  Enter a number (1-10), country code (e.g., US, GR, NL)," -ForegroundColor Gray
    Write-Host "  or press Enter for auto-recommended servers" -ForegroundColor Gray
    
    return $popular
}

function Show-Summary {
    param(
        [string]$OutputDir,
        [array]$GeneratedFiles,
        [string]$DNS
    )
    
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host "             CONFIGURATION GENERATION COMPLETE!             " -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Output Directory:" -ForegroundColor Yellow
    Write-Host "  $OutputDir" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Generated Files:" -ForegroundColor Yellow
    foreach ($file in $GeneratedFiles) {
        Write-Host "  [+] $($file.FileName)" -ForegroundColor Green
        Write-Host "      Server: $($file.Hostname)" -ForegroundColor Gray
        Write-Host "      Location: $($file.City), $($file.Country)" -ForegroundColor Gray
        Write-Host "      Load: $($file.Load)%" -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host " ROUTER CONFIGURATION REFERENCE" -ForegroundColor Yellow
    Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "  Interface Address  : 10.5.0.2/32" -ForegroundColor White
    Write-Host "  Endpoint Port      : 51820" -ForegroundColor White
    Write-Host "  DNS Servers        : $DNS" -ForegroundColor White
    Write-Host "  Allowed IPs        : 0.0.0.0/0, ::/0 (route all traffic)" -ForegroundColor White
    Write-Host "  Keepalive          : 25 seconds" -ForegroundColor White
    Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "[!] SECURITY REMINDER:" -ForegroundColor Yellow
    Write-Host "    - Keep your .conf files private - they contain your private key" -ForegroundColor Gray
    Write-Host "    - You can revoke your access token anytime from NordVPN dashboard" -ForegroundColor Gray
    Write-Host "    - Generate new configs if you suspect key compromise" -ForegroundColor Gray
    Write-Host ""
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
    Write-Host "  4. Copy the token (it starts with 'e9f...')"
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
    Write-Host "You can generate a new token at:" -ForegroundColor Gray
    Write-Host "https://my.nordaccount.com/dashboard/nordvpn/manual-configuration/" -ForegroundColor Cyan
    exit 1
}

Write-Host "[OK] Private key retrieved successfully!" -ForegroundColor Green

# ==================== STEP 3: Country Selection ====================
Write-Host ""
Write-Host "[STEP 3] Select Server Location" -ForegroundColor Green
Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray

$countries = Get-NordVPNCountries
$countryId = $null

if ($countries -and -not $Country) {
    $popularCountries = Show-CountryMenu -Countries $countries
    Write-Host ""
    $countryInput = Read-Host "Your choice"
    
    if ($countryInput) {
        # Check if input is a number
        if ($countryInput -match '^\d+$') {
            $num = [int]$countryInput
            if ($num -ge 1 -and $num -le $popularCountries.Count) {
                $code = $popularCountries[$num - 1].Code
                $selectedCountry = $countries | Where-Object { $_.code -eq $code }
                if ($selectedCountry) {
                    $countryId = $selectedCountry.id
                    Write-Host ""
                    Write-Host "[OK] Selected: $($selectedCountry.name)" -ForegroundColor Cyan
                }
            }
            else {
                Write-Host "[WARNING] Invalid number. Using recommended servers." -ForegroundColor Yellow
            }
        }
        else {
            # Input is a country code
            $selectedCountry = $countries | Where-Object { $_.code -eq $countryInput.ToUpper() }
            if ($selectedCountry) {
                $countryId = $selectedCountry.id
                Write-Host ""
                Write-Host "[OK] Selected: $($selectedCountry.name)" -ForegroundColor Cyan
            }
            else {
                Write-Host "[WARNING] Country code '$countryInput' not found. Using recommended servers." -ForegroundColor Yellow
            }
        }
    }
    else {
        Write-Host ""
        Write-Host "[OK] Using auto-recommended servers based on your location." -ForegroundColor Cyan
    }
}
elseif ($Country) {
    $selectedCountry = $countries | Where-Object { $_.code -eq $Country.ToUpper() }
    if ($selectedCountry) {
        $countryId = $selectedCountry.id
        Write-Host "[OK] Selected: $($selectedCountry.name)" -ForegroundColor Cyan
    }
    else {
        Write-Host "[WARNING] Country code '$Country' not found. Using recommended servers." -ForegroundColor Yellow
    }
}

# ==================== STEP 4: Configuration Options ====================
Write-Host ""
Write-Host "[STEP 4] Configuration Options" -ForegroundColor Green
Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host ""

# Number of configs
if ($ServerCount -eq 3) {
    $numInput = Read-Host "How many server configurations to generate? [3]"
    if ($numInput -match '^\d+$' -and [int]$numInput -gt 0 -and [int]$numInput -le 20) {
        $ServerCount = [int]$numInput
    }
    elseif ($numInput -and $numInput -notmatch '^\d+$') {
        Write-Host "[WARNING] Invalid number. Using default (3)." -ForegroundColor Yellow
    }
}

# DNS Selection
Write-Host ""
Write-Host "Select DNS servers:" -ForegroundColor Yellow
Write-Host ""
Write-Host "  1. NordVPN DNS      (103.86.96.100, 103.86.99.100) - Recommended"
Write-Host "  2. Cloudflare DNS   (1.1.1.1, 1.0.0.1) - Fast & Privacy-focused"
Write-Host "  3. Google DNS       (8.8.8.8, 8.8.4.4) - Reliable"
Write-Host "  4. Quad9 DNS        (9.9.9.9, 149.112.112.112) - Security-focused"
Write-Host "  5. Custom DNS"
Write-Host ""

$dnsChoice = Read-Host "Your choice [1]"
$dns = switch ($dnsChoice) {
    "2" { "1.1.1.1, 1.0.0.1" }
    "3" { "8.8.8.8, 8.8.4.4" }
    "4" { "9.9.9.9, 149.112.112.112" }
    "5" { 
        $customDns = Read-Host "Enter DNS servers (comma-separated, e.g., 1.1.1.1, 8.8.8.8)"
        if ($customDns) { $customDns } else { "103.86.96.100, 103.86.99.100" }
    }
    default { "103.86.96.100, 103.86.99.100" }
}

Write-Host ""
Write-Host "[OK] DNS configured: $dns" -ForegroundColor Cyan

# ==================== STEP 5: Generate Configurations ====================
Write-Host ""
Write-Host "[STEP 5] Generating WireGuard Configuration Files" -ForegroundColor Green
Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host ""
Write-Host "Fetching optimal servers from NordVPN..." -ForegroundColor Gray

$servers = Get-NordVPNServers -CountryId $countryId -Limit $ServerCount

if (-not $servers -or $servers.Count -eq 0) {
    Write-Host "[ERROR] No WireGuard-compatible servers found." -ForegroundColor Red
    Write-Host "        Try selecting a different country or check your connection." -ForegroundColor Gray
    exit 1
}

Write-Host "[OK] Found $($servers.Count) optimal servers" -ForegroundColor Green
Write-Host ""

# Create output directory
$outputDir = Join-Path -Path $PWD -ChildPath "NordVPN-WireGuard-Configs"
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

# Generate configuration files
$generatedFiles = @()
Write-Host "Generating configuration files..." -ForegroundColor Gray
Write-Host ""

foreach ($server in $servers) {
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
        FilePath = $filePath
        Hostname = $result.Hostname
        City     = $result.City
        Country  = $result.Country
        Load     = $result.Load
        ServerIP = $result.ServerIP
    }
    
    Write-Host "  [+] $fileName" -ForegroundColor Green
}

# Show summary
Show-Summary -OutputDir $outputDir -GeneratedFiles $generatedFiles -DNS $dns

# Offer to open folder
$openFolder = Read-Host "Open the output folder in Explorer? (Y/n)"
if ($openFolder -ne "n" -and $openFolder -ne "N") {
    Start-Process explorer.exe -ArgumentList $outputDir
}

Write-Host ""
Write-Host "Done! Import the .conf file(s) into your router's WireGuard client." -ForegroundColor Green
Write-Host ""

#endregion Main Script
