# NordVPN WireGuard Configuration Generator

<p align="center">
  <img src="https://img.shields.io/badge/PowerShell-5.1%2B-blue?logo=powershell" alt="PowerShell">
  <img src="https://img.shields.io/badge/Platform-Windows%20%7C%20Linux%20%7C%20macOS-lightgrey" alt="Platform">
  <img src="https://img.shields.io/badge/License-MIT-green" alt="License">
</p>

Generate WireGuard configuration files for NordVPN to use on your router or any WireGuard-compatible device.

## 🚀 Why This Tool?

NordVPN doesn't officially provide WireGuard configuration files. Their **NordLynx** protocol is built on WireGuard, but they only offer it through their apps. This tool uses NordVPN's API to generate standard WireGuard `.conf` files that work on:

- 🖥️ **Routers**: OpenWrt, OPNsense, pfSense, Ubiquiti, MikroTik, GL.iNet, ASUS, etc.
- 📱 **Devices**: Any device with WireGuard support
- 🐳 **Containers**: Docker, Gluetun, etc.

## ✨ Features

- ✅ **Interactive country selection** - Choose from popular presets or enter any country code
- ✅ **Server list with real-time metrics** - View all servers sorted by load
- ✅ **Color-coded load indicator** - Quickly identify best performing servers
- ✅ **Flexible server selection** - Pick specific servers or auto-select best ones
- ✅ **Multiple DNS options** - NordVPN, Cloudflare, Google, Quad9, or custom
- ✅ **No dependencies** - Uses only built-in PowerShell

## 📸 Screenshots

### Server Selection with Load Metrics
```
============================================================
 Available WireGuard Servers in United States
 Sorted by load (lowest = best performance)
============================================================

#    HOSTNAME                       CITY                 LOAD     IP ADDRESS
--------------------------------------------------------------------------------
1    us9432.nordvpn.com             New York             8%       192.145.32.45
2    us8821.nordvpn.com             Los Angeles          12%      185.216.35.12
3    us7623.nordvpn.com             Chicago              15%      194.128.44.78
4    us6512.nordvpn.com             Miami                23%      185.93.12.33
5    us5765.nordvpn.com             Dallas               35%      192.145.45.67
...

Load Legend: GREEN = Low (0-30%) | YELLOW = Medium (31-60%) | RED = High (61%+)
```

## 📋 Prerequisites

1. **Active NordVPN subscription**
2. **NordVPN Access Token** - [Get it here](https://my.nordaccount.com/dashboard/nordvpn/manual-configuration/)
3. **Windows PowerShell 5.1+** or **PowerShell Core 7+**

## 🔑 Getting Your Access Token

1. Go to [NordVPN Manual Configuration](https://my.nordaccount.com/dashboard/nordvpn/manual-configuration/)
2. Click **"Set up NordVPN Manually"**
3. Verify your identity if prompted
4. Click **"Generate new token"**
5. Select **"Get service credentials"** permission
6. Copy the token (starts with `e9f...`)

## 📥 Installation

### Option 1: Download directly
```powershell
# Download the script
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/merlini0s/nordvpn-wireguard-generator/main/NordVPN-WireGuard-Generator.ps1" -OutFile "NordVPN-WireGuard-Generator.ps1"
```

### Option 2: Clone the repository
```bash
git clone https://github.com/merlini0s/nordvpn-wireguard-generator.git
cd nordvpn-wireguard-generator
```

## 🎯 Usage

### Run the Script
```powershell
.\NordVPN-WireGuard-Generator.ps1
```

### Step-by-Step Flow

1. **Enter your access token**
2. **Select a country** - Choose from popular options or enter any country code (e.g., `US`, `GR`, `NL`)
3. **View server list** - See all available servers sorted by load with color-coded metrics
4. **Select servers** - Multiple options:
   - `1,3,5` - Pick specific servers by number
   - `best 5` - Auto-select top 5 lowest-load servers  
   - `all` - Generate configs for all servers
   - Press **Enter** - Default to top 3 best servers
5. **Choose DNS** - Select from preset options or enter custom DNS
6. **Done!** - Configuration files are saved to `NordVPN-WireGuard-Configs` folder

### Command Line Mode
```powershell
# Provide token directly (still interactive for server selection)
.\NordVPN-WireGuard-Generator.ps1 -Token "your_token_here"
```

## 📁 Output

The script creates a `NordVPN-WireGuard-Configs` folder containing `.conf` files:

```
NordVPN-WireGuard-Configs/
├── United_States-New_York-us9432.nordvpn.com.conf
├── United_States-Los_Angeles-us8821.nordvpn.com.conf
└── United_States-Chicago-us7623.nordvpn.com.conf
```

### Example Configuration File
```ini
# ============================================
# NordVPN WireGuard Configuration
# ============================================
# Server   : us9432.nordvpn.com
# Location : New York, United States
# Load     : 8%
# IP       : 192.145.32.45
# Generated: 2025-02-16 14:30:00
# ============================================

[Interface]
PrivateKey = YOUR_PRIVATE_KEY_HERE
Address = 10.5.0.2/32
DNS = 103.86.96.100, 103.86.99.100

[Peer]
PublicKey = SERVER_PUBLIC_KEY_HERE
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = 192.145.32.45:51820
PersistentKeepalive = 25
```

## 🔧 Router Setup Reference

| Setting | Value |
|---------|-------|
| Interface Address | `10.5.0.2/32` |
| Endpoint Port | `51820` |
| Allowed IPs | `0.0.0.0/0, ::/0` |
| Persistent Keepalive | `25` |
| NordVPN DNS | `103.86.96.100`, `103.86.99.100` |

## 🌍 Supported Countries

The script supports **all** NordVPN server locations. Popular quick-select options include:

| # | Country | Code | | # | Country | Code | | # | Country | Code |
|---|---------|------|---|---|---------|------|---|---|---------|------|
| 1 | United States | US | | 6 | France | FR | | 11 | Greece | GR |
| 2 | United Kingdom | GB | | 7 | Switzerland | CH | | 12 | Italy | IT |
| 3 | Germany | DE | | 8 | Sweden | SE | | 13 | Spain | ES |
| 4 | Netherlands | NL | | 9 | Japan | JP | | 14 | Poland | PL |
| 5 | Canada | CA | | 10 | Australia | AU | | 15 | Austria | AT |

You can also enter any valid [ISO 3166-1 alpha-2](https://en.wikipedia.org/wiki/ISO_3166-1_alpha-2) country code.

## 🎨 Load Color Coding

When viewing the server list, loads are color-coded for quick identification:

| Color | Load Range | Meaning |
|-------|------------|---------|
| 🟢 Green | 0-30% | Low load - Best performance |
| 🟡 Yellow | 31-60% | Medium load - Good performance |
| 🔴 Red | 61%+ | High load - May be slower |

## 🔐 Security Notes

- ⚠️ **Keep your `.conf` files private** - they contain your private key
- 🔄 **Revoke compromised tokens** immediately from NordVPN dashboard
- 🚫 **Never share** your access token or configuration files
- ✅ **Generate new configs** if you suspect any compromise

## 🛠️ Troubleshooting

### "Invalid or expired access token"
- Generate a new token from [NordVPN dashboard](https://my.nordaccount.com/dashboard/nordvpn/manual-configuration/)
- Ensure the token has "Get service credentials" permission

### "No WireGuard servers found"
- Try a different country
- Some locations may have limited WireGuard support

### Execution Policy Error
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Script won't run
Right-click the script and select "Run with PowerShell", or:
```powershell
powershell -ExecutionPolicy Bypass -File .\NordVPN-WireGuard-Generator.ps1
```

## 📚 Related Resources

- [NordVPN Manual Configuration](https://my.nordaccount.com/dashboard/nordvpn/manual-configuration/)
- [WireGuard Official Site](https://www.wireguard.com/)
- [OpenWrt WireGuard Setup](https://openwrt.org/docs/guide-user/services/vpn/wireguard/client)
- [OPNsense WireGuard Setup](https://docs.opnsense.org/manual/how-tos/wireguard-client.html)
- [Ubiquiti WireGuard Setup](https://help.ui.com/hc/en-us/articles/115005090007)

## 🤝 Contributing

Contributions are welcome! Feel free to:
- 🐛 Report bugs
- 💡 Suggest features
- 🔧 Submit pull requests

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## ⚠️ Disclaimer

This tool is not affiliated with, endorsed by, or connected to NordVPN or Nord Security. Use at your own risk. Always comply with NordVPN's Terms of Service.

---

<p align="center">
  Made with ❤️ by <a href="https://github.com/merlini0s">merlini0s</a>
</p>
