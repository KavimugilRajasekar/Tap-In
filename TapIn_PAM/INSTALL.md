# TapIn PAM Module and Daemons - Installation Guide

This document provides comprehensive instructions for installing the TapIn authentication system on Linux systems.

## Table of Contents
1. [Overview](#overview)
2. [System Requirements](#system-requirements)
3. [Installation](#installation)
4. [Configuration](#configuration)
5. [Usage](#usage)
6. [Troubleshooting](#troubleshooting)
7. [Uninstall](#uninstall)

## Overview

TapIn is a PAM (Pluggable Authentication Module) system that enables passwordless authentication using a mobile device with Bluetooth and fingerprint capabilities. The system consists of:

- **PAM Module**: `libtapin_pam.so` - Handles authentication in the PAM stack
- **Helper Daemon**: `tapin_helper` - Validates authentication requests and creates tokens
- **Bluetooth Daemon**: `bluetooth_listener` - Receives authentication requests via Bluetooth
- **Systemd Services**: For managing the daemons

## System Requirements

### Supported Linux Distributions
- Ubuntu 20.04+ / Debian 11+
- Fedora 35+ / RHEL / CentOS / Rocky Linux / AlmaLinux
- openSUSE / SLES
- Arch Linux / Manjaro

### Hardware Requirements
- Bluetooth adapter (USB or built-in)
- Root access for installation

### Software Dependencies
The installer will automatically install these dependencies:
- `build-essential` (gcc, make) - Compilation tools
- `libpam0g-dev` - PAM development libraries
- `libjson-c-dev` - JSON parsing library
- `libssl-dev` - SSL/TLS libraries
- `libbluetooth-dev` - Bluetooth development libraries
- `pkg-config` - Package configuration tool
- `bluetooth` - Bluetooth service

## Installation

### Using the Installer Script (Recommended)

1. **Navigate to the project directory:**
   ```bash
   cd /path/to/Tap-In/TapIn_PAM
   ```

2. **Run the installer:**
   ```bash
   ./scripts/installer.sh
   ```
   
   The installer will:
   - Detect your Linux distribution
   - Install required dependencies
   - Create a backup of any existing installation
   - Build the TapIn modules and daemons
   - Install binaries to system locations
   - Configure PAM and systemd services
   - Generate a shared secret for HMAC validation
   - Start and enable the services

### Manual Installation

If you prefer to install manually, follow these steps:

1. **Install dependencies** (based on your distribution):
   
   **Ubuntu/Debian:**
   ```bash
   sudo apt update
   sudo apt install build-essential libpam0g-dev libjson-c-dev libssl-dev libbluetooth-dev pkg-config bluetooth
   ```

   **Fedora/RHEL/CentOS:**
   ```bash
   sudo dnf install gcc make pam-devel json-c-devel openssl-devel bluez-devel bluez
   ```

   **openSUSE:**
   ```bash
   sudo zypper install gcc make pam-devel libjson-c-devel libopenssl-devel bluez-devel
   ```

   **Arch/Manjaro:**
   ```bash
   sudo pacman -S base-devel pam json-c openssl bluez bluez-utils
   ```

2. **Build the project:**
   ```bash
   make
   ```

3. **Install manually:**
   ```bash
   sudo make install
   ```

## Configuration

### PAM Integration

To enable TapIn authentication for a service (like login, sudo, etc.), add the following line to the appropriate PAM configuration file:

```
auth sufficient pam_tapin.so
```

For example, to enable for login:
```bash
sudo nano /etc/pam.d/login
```

Add the line to the auth section:
```
auth    [success=ok default=1]  pam_selinux.so close
auth    sufficient              pam_tapin.so
auth    required                pam_unix.so try_first_pass
```

### Shared Secret

The installer generates a shared secret at `/etc/tapin/shared_secret`. This secret is used for HMAC validation between the mobile app and the Linux system. You must configure the same secret in your Flutter app for authentication to work.

### Bluetooth Pairing

1. Pair your mobile device with the Linux system via Bluetooth
2. Ensure the devices are trusted/paired permanently
3. Verify Bluetooth service is running: `sudo systemctl status bluetooth`

## Usage

### Service Management

The installer creates two systemd services:

- `tapin-helper.service` - Helper daemon
- `tapin-bluetooth.service` - Bluetooth listener daemon

**Check service status:**
```bash
sudo systemctl status tapin-helper.service tapin-bluetooth.service
```

**View service logs:**
```bash
sudo journalctl -u tapin-helper.service -f
sudo journalctl -u tapin-bluetooth.service -f
```

**Restart services:**
```bash
sudo systemctl restart tapin-helper.service tapin-bluetooth.service
```

### Authentication Flow

1. User opens the TapIn Flutter app
2. User authenticates with fingerprint
3. App creates signed authentication request with HMAC
4. Request is sent via Bluetooth to Linux system
5. Bluetooth daemon validates and forwards to helper daemon
6. Helper daemon validates HMAC signature and creates temporary token
7. PAM module reads token and authenticates user for login

## Troubleshooting

### Common Issues

1. **Bluetooth connection fails:**
   - Check if Bluetooth service is running: `sudo systemctl status bluetooth`
   - Verify devices are properly paired
   - Check Bluetooth adapter: `hciconfig`

2. **PAM authentication doesn't work:**
   - Verify PAM module is properly installed: `ls -la /lib/security/libtapin_pam.so`
   - Check PAM configuration files
   - Ensure daemons are running: `sudo systemctl status tapin-*`

3. **Services won't start:**
   - Check logs: `sudo journalctl -u tapin-* -f`
   - Verify dependencies are installed
   - Check file permissions

### Debugging

Enable debug logging by modifying the daemon configurations or checking system logs:

```bash
# Check system logs
sudo journalctl -f

# Check specific TapIn logs
sudo journalctl -u tapin-helper.service -f
sudo journalctl -u tapin-bluetooth.service -f
```

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

## Uninstall

### Using the Installer Script

To uninstall TapIn:

```bash
sudo ./scripts/installer.sh --uninstall
```

### Manual Uninstall

To manually uninstall:

```bash
sudo make uninstall
```

### Rollback

If you have a previous installation and want to rollback:

```bash
sudo ./scripts/installer.sh --rollback
```

## Support

For support, please check the logs and verify all installation steps were completed successfully. If you encounter issues:

1. Check the system logs
2. Verify all dependencies are installed
3. Ensure Bluetooth is working properly
4. Confirm the shared secret matches between mobile app and Linux system

## Notes

- The installation is designed to be safe and reversible
- A backup is created before installation
- The system is compatible with most Linux distributions
- Always test authentication in a safe environment before deploying in production