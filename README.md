# 👻 Phantom-Droid

**Resilient Android Wireless Debugging for macOS - Multi-Device Support**

Never plug in your Android devices again. Phantom-Droid keeps all your phones connected for wireless debugging 24/7, automatically reconnecting when ports change, networks switch, or your Mac wakes from sleep.

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
| 📱 **Multi-Device** | Manage unlimited Android devices |
| 🔄 **Auto-Reconnect** | Watchdog monitors all devices every 2 minutes |
| 🔍 **Smart Discovery** | Uses mDNS + port scanning when ports change |
| 🌐 **Network Aware** | Reconnects when Wi-Fi changes |
| 😴 **Wake Handler** | Reconnects all devices after Mac wakes from sleep |
| 💾 **Port Persistence** | Remembers last working port per device |
| 📊 **Status Dashboard** | Beautiful CLI status for all devices |
| 🧙 **Pairing Wizard** | Interactive setup for new devices |

## 📋 Requirements

- macOS 10.15+
- Android 11+ devices (for wireless debugging)
- Android SDK with platform-tools
- All devices on the same Wi-Fi network

## 🚀 Quick Start

### 1. Clone & Install

```bash
git clone https://github.com/m-awadi/phantom-droid.git
cd phantom-droid
./install.sh
```

### 2. Add Your First Device

Use the interactive pairing wizard:

```bash
source ~/.zshrc   # Or open new terminal
ppair
```

Or manually:

```bash
# On phone: Settings → Developer Options → Wireless debugging → Pair device
adb pair 192.168.1.100:37000 123456

# Add to phantom-droid
padd myphone 192.168.1.100
```

### 3. Connect!

```bash
phantom              # Connect default device
phantom -a           # Connect ALL devices
```

## 📱 Multi-Device Management

### Adding Devices

```bash
# Interactive wizard (recommended)
ppair

# Manual add
padd oneplus 192.168.1.100
padd pixel 192.168.1.101
padd samsung 192.168.1.102
```

### Managing Devices

```bash
# List all devices
plist
phantom -l

# Remove a device
premove pixel

# Set default device
pdefault samsung

# Edit config directly
nano ~/.phantom-droid/devices.conf
```

### Configuration File

```bash
# ~/.phantom-droid/devices.conf
oneplus=192.168.1.100
pixel=192.168.1.101
samsung=192.168.1.102
```

The first device is the default.

## 🎮 Commands

### Connection Commands

| Command | Description |
|---------|-------------|
| `phantom` | Connect default device |
| `phantom pixel` | Connect specific device |
| `phantom -a` | Connect ALL devices |
| `phantom -r` | Reset ADB and reconnect (fixes stale connections) |
| `phantom -l` | List all devices |
| `pdisconnect` | Disconnect default device |
| `pdisconnect -a` | Disconnect ALL devices |
| `prestart` | Reconnect all devices |

### Device Management

| Command | Description |
|---------|-------------|
| `ppair` | Interactive pairing wizard |
| `padd <name> <ip>` | Add new device |
| `premove <name>` | Remove device |
| `plist` | List configured devices |
| `pdefault <name>` | Set default device |

### Device Interaction

| Command | Description |
|---------|-------------|
| `pstatus` | Show status of all devices |
| `pshell` | Shell into default device |
| `pshell pixel` | Shell into 'pixel' |
| `plog` | Logcat from default device |
| `plog pixel` | Logcat from 'pixel' |
| `pinstall app.apk` | Install APK to default device |
| `pscrcpy` | Mirror default device screen |
| `pscrcpy pixel` | Mirror 'pixel' screen |

## 📁 Project Structure

```
phantom-droid/
├── README.md
├── LICENSE
├── install.sh
├── uninstall.sh
├── scripts/
│   ├── phantom-connect.sh      # Smart multi-device connection
│   ├── phantom-disconnect.sh   # Disconnect devices
│   ├── phantom-status.sh       # Status dashboard
│   ├── phantom-watchdog.sh     # Connection monitor (all devices)
│   ├── phantom-device.sh       # Device management (add/remove)
│   └── phantom-pair.sh         # Interactive pairing wizard
└── launchagents/
    ├── com.phantom-droid.watchdog.plist
    └── com.phantom-droid.wake.plist
```

### Installed Files

```
~/bin/
├── phantom-connect.sh
├── phantom-disconnect.sh
├── phantom-status.sh
├── phantom-watchdog.sh
├── phantom-device.sh
└── phantom-pair.sh

~/Library/LaunchAgents/
├── com.phantom-droid.watchdog.plist
└── com.phantom-droid.wake.plist

~/.phantom-droid/
├── devices.conf          # Device configuration
├── port_oneplus          # Saved port for 'oneplus'
├── port_pixel            # Saved port for 'pixel'
└── ...
```

## 🔧 Configuration

### View/Edit Devices

```bash
# List devices
plist

# Edit config file
nano ~/.phantom-droid/devices.conf
```

### View Logs

```bash
# All logs
tail -f /tmp/phantom-droid.log

# Watchdog logs
tail -f /tmp/phantom-droid-watchdog.log
```

### Service Control

```bash
# Stop watchdog
launchctl unload ~/Library/LaunchAgents/com.phantom-droid.watchdog.plist

# Start watchdog
launchctl load ~/Library/LaunchAgents/com.phantom-droid.watchdog.plist

# Check status
launchctl list | grep phantom
```

## 🗑️ Uninstall

```bash
cd phantom-droid
./uninstall.sh
```

## ⚠️ Wireless Debugging Limitations

Android's wireless debugging has built-in limitations that **cannot be bypassed without root**:

| Event | What Happens | Solution |
|-------|--------------|----------|
| **Phone reboot** | Wireless debugging disabled | Must re-enable manually on phone |
| **Network change** | Wireless debugging disabled | Must re-enable manually on phone |
| **Toggle off/on** | Port changes, may need re-pair | Phantom auto-discovers new port |
| **Authorization prompt** | Connection shows "offline" | Tap "Allow" on phone |

### Maximizing Uptime (Without Root)

To keep your device connected as long as possible:

1. **Stable WiFi** - Keep phone on the same network, avoid switching
2. **Always allow** - Check "Always allow from this computer" when authorizing
3. **Keep powered** - Plug phone into charger to prevent battery saver
4. **Avoid reboots** - Don't restart the phone unless necessary
5. **Static IP** - Assign via router DHCP reservation

### Truly Touchless Options

| Method | Touchless | Survives Reboot | Setup |
|--------|-----------|-----------------|-------|
| **Wireless debugging** | ❌ | ❌ | Enable on phone after each reboot |
| **USB + tcpip** | ⚠️ | ❌ | Run `adb tcpip 5555` via USB after reboot |
| **USB hub** | ✅ | ✅ | Keep phone permanently connected via USB |
| **Root + Magisk** | ✅ | ✅ | Install ADB over TCP module |

### With Root (Magisk)

For truly touchless operation, root your device and either:

1. Install **ADB over TCP** Magisk module, or
2. Add to a boot script:
```bash
setprop service.adb.tcp.port 5555
stop adbd
start adbd
```

## 🐛 Troubleshooting

### "Could not connect to device"

1. **Check Wi-Fi**: Device must be on same network as Mac
2. **Check Wireless Debugging**: Must be enabled on phone
3. **Re-pair**: `adb pair <ip>:<port> <code>`
4. **Check IP**: Device IP may have changed
5. **Reset ADB**: Run `adb kill-server && phantom` to clear stale connections

### Device shows "offline"

Your phone is showing an authorization prompt. Check your phone screen and tap **"Allow"**. Check "Always allow from this computer" to avoid this in the future.

### Port keeps changing

This is normal on Android 11+. Phantom-Droid handles this via:
1. mDNS discovery
2. Port range scanning (37000-45000)

### One device connects, another doesn't

- Each device needs separate pairing
- Run `ppair` for each new device
- Verify each device has correct static IP

### Connection fails after network change

Wireless debugging disables itself when the network changes. You must:
1. Re-enable wireless debugging on the phone
2. Run `phantom` to reconnect

### Watchdog not running

```bash
# Check status
launchctl list | grep phantom-droid

# Reload
launchctl unload ~/Library/LaunchAgents/com.phantom-droid.watchdog.plist
launchctl load ~/Library/LaunchAgents/com.phantom-droid.watchdog.plist
```

## 🏠 Physical Setup Tips

For dedicated debugging phones:

| Component | Recommendation |
|-----------|----------------|
| **Charger** | Use slow charger (5V/1A) per device |
| **Location** | Well-ventilated area |
| **Screen** | Set timeout to 15 seconds |
| **Wi-Fi** | Developer Options → Keep Wi-Fi on during sleep → Always |
| **Static IP** | Assign via router DHCP reservation |

## 📄 License

MIT License - feel free to use and modify!

## 🙏 Credits

Created with ❤️ for Android developers who are tired of cables.

---

*Your phones are always there. Invisible. Connected. Like phantoms.* 👻
