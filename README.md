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

- ✅ Interactive wizard - guides you through the process
- ✅ Country selection with popular presets
- ✅ Multiple DNS options (NordVPN, Cloudflare, Google, Quad9, Custom)
- ✅ Generate multiple server configs at once
- ✅ Shows server load for optimal selection
- ✅ No dependencies - uses only built-in PowerShell

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

### Interactive Mode (Recommended)
```powershell
.\NordVPN-WireGuard-Generator.ps1
```

The script will guide you through:
1. Entering your access token
2. Selecting a country
3. Choosing number of configs
4. Selecting DNS servers

### Command Line Mode
```powershell
# Generate 5 US server configs
.\NordVPN-WireGuard-Generator.ps1 -Token "your_token_here" -Country "US" -ServerCount 5

# Generate configs for Germany
.\NordVPN-WireGuard-Generator.ps1 -Token "your_token_here" -Country "DE"
```

### Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `-Token` | Your NordVPN access token | _(prompted)_ |
| `-Country` | Country code (US, GB, DE, NL, etc.) | _(auto/prompted)_ |
| `-ServerCount` | Number of configs to generate | 3 |

## 📁 Output

The script creates a `NordVPN-WireGuard-Configs` folder containing `.conf` files:

```
NordVPN-WireGuard-Configs/
├── United_States-New_York-us1234.nordvpn.com.conf
├── United_States-Los_Angeles-us5678.nordvpn.com.conf
└── United_States-Chicago-us9012.nordvpn.com.conf
```

### Example Configuration File
```ini
[Interface]
PrivateKey = YOUR_PRIVATE_KEY_HERE
Address = 10.5.0.2/32
DNS = 103.86.96.100, 103.86.99.100

[Peer]
PublicKey = SERVER_PUBLIC_KEY_HERE
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = SERVER_IP:51820
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

The script supports all NordVPN server locations. Popular options include:

| Code | Country | Code | Country |
|------|---------|------|---------|
| US | United States | JP | Japan |
| GB | United Kingdom | AU | Australia |
| DE | Germany | CA | Canada |
| NL | Netherlands | FR | France |
| CH | Switzerland | SE | Sweden |

Use any valid [ISO 3166-1 alpha-2](https://en.wikipedia.org/wiki/ISO_3166-1_alpha-2) country code.

## 🔐 Security Notes

- ⚠️ **Keep your `.conf` files private** - they contain your private key
- 🔄 **Revoke compromised tokens** immediately from NordVPN dashboard
- 🚫 **Never share** your access token or configuration files
- ✅ **Generate new configs** if you suspect any compromise

## 🛠️ Troubleshooting

### "Invalid or expired access token"
- Generate a new token from [NordVPN dashboard](https://my.nordaccount.com/dashboard/nordvpn/manual-configuration/)
- Ensure the token has "Get service credentials" permission

### "Could not fetch country list"
- Check your internet connection
- NordVPN API might be temporarily unavailable

### "No WireGuard-compatible servers found"
- Try a different country
- Some locations may have limited WireGuard support

### Execution Policy Error
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## 📚 Related Resources

- [NordVPN Manual Configuration](https://my.nordaccount.com/dashboard/nordvpn/manual-configuration/)
- [WireGuard Official Site](https://www.wireguard.com/)
- [OpenWrt WireGuard Setup](https://openwrt.org/docs/guide-user/services/vpn/wireguard/client)
- [OPNsense WireGuard Setup](https://docs.opnsense.org/manual/how-tos/wireguard-client.html)

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
  Made with ❤️ for the router enthusiast community
</p>
