# TapIn PAM Module Deployment Guide

## Overview

This guide explains how to deploy the TapIn PAM module system on a Linux system to enable passwordless login using a mobile device with fingerprint authentication.

## Prerequisites

### System Requirements
- Linux distribution with PAM support (Ubuntu, Debian, Fedora, etc.)
- Bluetooth adapter (USB or built-in)
- Root access for installation
- Development tools (if building from source)

### Dependencies
```bash
# On Ubuntu/Debian:
sudo apt-get update
sudo apt-get install build-essential libpam0g-dev libjson-c-dev libssl-dev libbluetooth-dev

# On Fedora/RHEL:
sudo dnf install gcc make pam-devel json-c-devel openssl-devel bluez-devel
```

## Installation Steps

### 1. Clone or Download the Source Code
```bash
# Navigate to your TapIn project directory
cd /path/to/Tap-In/TapIn_PAM
```

### 2. Build the Components
```bash
make
```

### 3. Install All Components
```bash
sudo make install
```

This will:
- Install the PAM module to `/lib/security/libtapin_pam.so`
- Install daemons to `/usr/local/bin/`
- Create configuration files in `/etc/tapin/` and `/etc/pam.d/`
- Install systemd service files
- Reload the systemd daemon

### 4. Configure the Shared Secret

The shared secret is used for HMAC validation between the mobile app and Linux system:

```bash
# Generate a strong shared secret (32 bytes hex)
sudo openssl rand -hex 32 > /etc/tapin/shared_secret
sudo chmod 600 /etc/tapin/shared_secret

# Note: You'll need to use the same secret in the Flutter app
```

### 5. Enable and Start the Services

```bash
sudo make enable-services
# Or manually:
sudo systemctl enable tapin-helper.service tapin-bluetooth.service
sudo systemctl start tapin-helper.service tapin-bluetooth.service
```

### 6. Configure PAM for Your Login Manager

You need to add the TapIn PAM module to your login manager's configuration. Edit the appropriate file:

For GDM (GNOME):
```bash
sudo nano /etc/pam.d/gdm
```

For LightDM:
```bash
sudo nano /etc/pam.d/lightdm
```

For SDDM (KDE):
```bash
sudo nano /etc/pam.d/sddm
```

For console login:
```bash
sudo nano /etc/pam.d/login
```

Add this line in the `auth` section (usually near the top):
```
auth    sufficient    pam_tapin.so
```

Example complete configuration:
```
#%PAM-1.0

auth    sufficient    pam_tapin.so
auth    required      pam_unix.so try_first_pass nullok
account required      pam_unix.so
session required      pam_unix.so
```

## Configuration Details

### Bluetooth Settings
The Bluetooth listener runs on RFCOMM channel 1. Ensure your mobile app connects to the correct channel.

### Shared Secret Format
The shared secret in `/etc/tapin/shared_secret` should be a 32-byte hex string (64 characters). This same secret must be configured in the Flutter app for HMAC validation to work.

### Token File
Authentication tokens are stored in `/var/run/tapin_auth.token` and are automatically cleaned up after use.

## Testing the Installation

### 1. Verify Services are Running
```bash
sudo make status-services
# Or manually:
sudo systemctl status tapin-helper.service tapin-bluetooth.service
```

### 2. Check PAM Module
```bash
ls -la /lib/security/libtapin_pam.so
```

### 3. Check Bluetooth Service
```bash
sudo systemctl status bluetooth
```

### 4. Monitor Logs
```bash
sudo journalctl -u tapin-bluetooth.service -f
sudo journalctl -u tapin-helper.service -f
# Or check system logs:
sudo tail -f /var/log/syslog | grep tapin
```

## Mobile App Configuration

### 1. Bluetooth Pairing
- Pair your mobile device with the Linux system via Bluetooth
- Ensure the devices are trusted/paired permanently

### 2. Shared Secret
- The Flutter app must use the same shared secret stored in `/etc/tapin/shared_secret`
- This secret is used to generate HMAC signatures for authentication requests

### 3. Authentication Flow
1. Open the TapIn Flutter app
2. Select your Linux system from Bluetooth scan results
3. Save your Linux credentials (username/password) with fingerprint verification
4. At the Linux login screen, use the "TouchPass" feature to authenticate
5. The app will send a signed authentication request via Bluetooth

## Security Considerations

### File Permissions
- `/etc/tapin/shared_secret`: Only readable by root (600)
- `/var/run/tapin_auth.token`: Only readable by root (600)
- PAM module: Proper permissions (644)

### Bluetooth Security
- Only paired/trusted devices should be able to connect
- Bluetooth communication should use encryption
- Consider using fixed PIN codes for pairing

### Token Security
- Tokens expire after 20 seconds
- Tokens are consumed after single use
- Tokens are tied to specific users

## Troubleshooting

### Common Issues

1. **Bluetooth connection fails**:
   - Ensure Bluetooth service is running: `sudo systemctl status bluetooth`
   - Check if devices are properly paired
   - Verify Bluetooth adapter is working

2. **PAM authentication doesn't work**:
   - Check that the PAM module is properly installed
   - Verify PAM configuration files
   - Ensure daemons are running

3. **Services won't start**:
   - Check logs: `sudo journalctl -u tapin-* -f`
   - Verify dependencies are installed
   - Check file permissions

### Debug Commands
```bash
# Check if services are running
sudo systemctl status tapin-helper tapin-bluetooth

# View service logs
sudo journalctl -u tapin-helper --no-pager
sudo journalctl -u tapin-bluetooth --no-pager

# Check PAM configuration
grep tapin /etc/pam.d/*
```

## Uninstalling

To completely remove the TapIn PAM system:
```bash
sudo make uninstall
```

This will:
- Stop and disable the systemd services
- Remove the PAM module
- Remove the daemon executables
- Remove configuration files
- Remove systemd service files
- Reload the systemd daemon

## Verification

After installation, verify the complete system works:
1. Services are running
2. Bluetooth listener is accepting connections
3. PAM configuration is active
4. Mobile app can connect and authenticate
5. Linux login accepts the authentication

## Notes

- The system is designed to be "sufficient" in PAM terms, meaning if it succeeds, login is granted without requiring a password
- If the PAM module fails (no valid token), the system falls back to normal password authentication
- Always test the system thoroughly before relying on it as the sole authentication method