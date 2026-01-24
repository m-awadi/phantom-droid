# 👻 Phantom-Droid

**Resilient Android Wireless Debugging for macOS**

Never plug in your Android device again. Phantom-Droid keeps your phone connected for wireless debugging 24/7, automatically reconnecting when ports change, networks switch, or your Mac wakes from sleep.

```
   ██████╗ ██╗  ██╗ █████╗ ███╗   ██╗████████╗ ██████╗ ███╗   ███╗
   ██╔══██╗██║  ██║██╔══██╗████╗  ██║╚══██╔══╝██╔═══██╗████╗ ████║
   ██████╔╝███████║███████║██╔██╗ ██║   ██║   ██║   ██║██╔████╔██║
   ██╔═══╝ ██╔══██║██╔══██║██║╚██╗██║   ██║   ██║   ██║██║╚██╔╝██║
   ██║     ██║  ██║██║  ██║██║ ╚████║   ██║   ╚██████╔╝██║ ╚═╝ ██║
   ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝   ╚═╝    ╚═════╝ ╚═╝     ╚═╝
                      ██████╗ ██████╗  ██████╗ ██╗██████╗
                      ██╔══██╗██╔══██╗██╔═══██╗██║██╔══██╗
                      ██║  ██║██████╔╝██║   ██║██║██║  ██║
                      ██║  ██║██╔══██╗██║   ██║██║██║  ██║
                      ██████╔╝██║  ██║╚██████╔╝██║██████╔╝
                      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚═╝╚═════╝
```

## ✨ Features

| Feature | Description |
|---------|-------------|
| 🔄 **Auto-Reconnect** | Watchdog monitors connection every 2 minutes |
| 🔍 **Smart Discovery** | Uses mDNS + port scanning when port changes |
| 🌐 **Network Aware** | Reconnects when Wi-Fi changes |
| 😴 **Wake Handler** | Reconnects after Mac wakes from sleep |
| 💾 **Port Persistence** | Remembers last working port |
| 📊 **Status Dashboard** | Beautiful CLI status display |

## 📋 Requirements

- macOS 10.15+
- Android 11+ device (for wireless debugging)
- Android SDK with platform-tools
- Both devices on the same Wi-Fi network

## 🚀 Quick Start

### 1. Clone & Install

```bash
git clone https://github.com/m-awadi/phantom-droid.git
cd phantom-droid
./install.sh
```

### 2. One-Time Phone Setup

1. **Enable Developer Options**
   - Settings → About Phone → Tap "Build Number" 7 times

2. **Enable Wireless Debugging**
   - Settings → Developer Options → Wireless debugging → ON

3. **Assign Static IP** (recommended)
   - Settings → Wi-Fi → Your Network → Edit → IP settings: Static
   - Or configure DHCP reservation on your router

### 3. Initial Pairing (one-time)

On your phone: Wireless debugging → **Pair device with pairing code**

```bash
adb pair <ip>:<pairing-port> <6-digit-code>
```

### 4. Connect!

```bash
# Open new terminal or reload shell
source ~/.zshrc

# Connect
phantom
```

## 🎮 Commands

| Command | Description |
|---------|-------------|
| `phantom` | Connect to device (auto-discovers port) |
| `pstatus` | Show connection status & device info |
| `pshell` | Open ADB shell on device |
| `plog` | View logcat |
| `pinstall app.apk` | Install APK |
| `pscrcpy` | Mirror screen (requires [scrcpy](https://github.com/Genymobile/scrcpy)) |
| `pdisconnect` | Disconnect from device |
| `prestart` | Force reconnect |

## 📁 What Gets Installed

```
~/bin/
├── phantom-connect.sh      # Smart connection script
├── phantom-disconnect.sh   # Disconnect script
├── phantom-status.sh       # Status display
└── phantom-watchdog.sh     # Connection monitor

~/Library/LaunchAgents/
├── com.phantom-droid.watchdog.plist   # Auto-reconnect service
└── com.phantom-droid.wake.plist       # Wake handler

~/.phantom-droid/
├── device_ip               # Configured device IP
└── port                    # Last known working port
```

## 🔧 Configuration

### Change Device IP

Edit `~/.phantom-droid/device_ip` or set environment variable:

```bash
export PHANTOM_DEVICE_IP="192.168.1.200"
```

### View Logs

```bash
# Connection logs
tail -f /tmp/phantom-droid.log

# Watchdog logs
tail -f /tmp/phantom-droid-watchdog.log
```

### Manual Service Control

```bash
# Stop watchdog
launchctl unload ~/Library/LaunchAgents/com.phantom-droid.watchdog.plist

# Start watchdog
launchctl load ~/Library/LaunchAgents/com.phantom-droid.watchdog.plist
```

## 🗑️ Uninstall

```bash
./uninstall.sh
```

## 🐛 Troubleshooting

### "Could not connect to device"

1. **Check Wi-Fi**: Both devices must be on the same network
2. **Check Wireless Debugging**: Must be enabled on phone
3. **Re-pair**: The pairing might have expired
   ```bash
   adb pair <ip>:<port> <code>
   ```

### Port keeps changing

This is normal on Android 11+. Phantom-Droid handles this automatically via:
1. mDNS discovery
2. Port range scanning (37000-45000)

### Connection drops frequently

- Keep phone plugged into power
- Disable battery optimization for "Wireless debugging"
- Use 5GHz Wi-Fi if available

## 🏠 Physical Setup Tips

For a dedicated debugging phone:

| Component | Recommendation |
|-----------|----------------|
| **Charger** | Use slow charger (5V/1A) to preserve battery |
| **Location** | Well-ventilated, away from heat |
| **Screen** | Set timeout to 15 seconds |
| **Wi-Fi** | Developer Options → Keep Wi-Fi on during sleep → Always |

## 📄 License

MIT License - feel free to use and modify!

## 🙏 Credits

Created with ❤️ for Android developers who are tired of cables.

---

*Your phone is always there. Invisible. Connected. Like a phantom.* 👻
