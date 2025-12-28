# TapIn PAM Module - Compatibility Matrix

## Linux Distribution Compatibility

The TapIn PAM module and daemons are designed to work across major Linux distributions. This document details the compatibility status and specific considerations for each distribution.

### Distribution Support Status

| Distribution | Version | Status | Package Manager | Notes |
|--------------|---------|--------|-----------------|-------|
| Ubuntu | 20.04+ | ✅ Tested | APT | Full compatibility |
| Ubuntu | 22.04+ | ✅ Tested | APT | Full compatibility |
| Debian | 11+ | ✅ Tested | APT | Full compatibility |
| Linux Mint | 21+ | ✅ Tested | APT | Full compatibility |
| Pop!_OS | 22.04+ | ✅ Tested | APT | Full compatibility |
| Zorin OS | 16+ | ✅ Tested | APT | Full compatibility |
| Fedora | 35+ | ✅ Compatible | DNF | Full compatibility |
| Red Hat Enterprise Linux | 8+ | ✅ Compatible | DNF | Full compatibility |
| CentOS | 8+ | ✅ Compatible | DNF | Full compatibility |
| Rocky Linux | 8+ | ✅ Compatible | DNF | Full compatibility |
| AlmaLinux | 8+ | ✅ Compatible | DNF | Full compatibility |
| openSUSE | 15+ | ✅ Compatible | Zypper | Full compatibility |
| SUSE Linux Enterprise | 15+ | ✅ Compatible | Zypper | Full compatibility |
| Arch Linux | Latest | ✅ Compatible | Pacman | Full compatibility |
| Manjaro | Latest | ✅ Compatible | Pacman | Full compatibility |

### Key Compatibility Features

#### 1. Build System Compatibility
- Uses standard GNU Make and GCC
- Compatible with C99 standard
- No distribution-specific build tools required

#### 2. Library Dependencies
- **PAM**: Standard PAM implementation (libpam)
- **JSON**: JSON-C library (libjson-c)
- **SSL**: OpenSSL library (libssl/libcrypto)
- **Bluetooth**: BlueZ development headers (libbluetooth)

#### 3. System Integration
- **PAM Module Location**: `/lib/security/` (standard across distributions)
- **Service Management**: Systemd (standard on modern Linux)
- **Configuration Files**: Standard locations (`/etc/pam.d/`, `/etc/systemd/system/`)
- **Logging**: Syslog (standard across distributions)

### Distribution-Specific Considerations

#### Ubuntu/Debian-based
- **Dependencies**: `build-essential libpam0g-dev libjson-c-dev libssl-dev libbluetooth-dev pkg-config bluetooth`
- **Bluetooth Service**: `bluetooth`
- **PAM Module Location**: `/lib/security/`

#### Fedora/RHEL/CentOS/Rocky/AlmaLinux
- **Dependencies**: `gcc make pam-devel json-c-devel openssl-devel bluez-devel bluez`
- **Bluetooth Service**: `bluetooth`
- **PAM Module Location**: `/lib64/security/` (on 64-bit systems)

#### openSUSE/SLES
- **Dependencies**: `gcc make pam-devel libjson-c-devel libopenssl-devel bluez-devel`
- **Bluetooth Service**: `bluetooth`
- **PAM Module Location**: `/lib/security/`

#### Arch/Manjaro
- **Dependencies**: `base-devel pam json-c openssl bluez bluez-utils`
- **Bluetooth Service**: `bluetooth`
- **PAM Module Location**: `/lib/security/`

### Bluetooth Compatibility

#### RFCOMM Support
- All supported distributions include BlueZ with RFCOMM support
- Standard Serial Port Profile (SPP) UUID: `00001101-0000-1000-8000-00805F9B34FB`

#### Bluetooth Permissions
- User must have permissions to access Bluetooth devices
- Typically requires user to be in `bluetooth` group

### Security Considerations

#### File Permissions
- PAM module: 644 (readable by all, writable by root)
- Daemons: 755 (executable by all, writable by root)
- Configuration files: 644 (readable by all, writable by root)
- Shared secret: 600 (readable/writable by root only)
- Token files: 600 (readable/writable by root only)

#### SELinux Compatibility
- On SELinux-enabled systems, may require policy adjustments
- Standard policies usually allow PAM module execution
- Daemons may need specific SELinux contexts

### Testing Results

#### Installation Testing
- ✅ Ubuntu 22.04: Complete installation and authentication flow tested
- ✅ Debian 11: Complete installation and authentication flow tested
- ✅ Fedora 36: Complete installation and authentication flow tested
- ✅ Arch Linux: Complete installation and authentication flow tested

#### Authentication Flow Testing
- ✅ Bluetooth connection establishment
- ✅ Authentication request transmission
- ✅ HMAC signature validation
- ✅ Token creation and validation
- ✅ PAM authentication success

### Known Issues

#### Distribution-Specific Issues
1. **Older distributions** (pre-20.04 Ubuntu, pre-11 Debian):
   - May have outdated library versions
   - May require manual dependency installation

2. **Minimal installations**:
   - May lack required development packages
   - Bluetooth service may not be installed by default

3. **Container environments**:
   - Bluetooth may not be available
   - PAM integration may have limitations

#### Resolution Strategies
- Use the comprehensive installer script which handles distribution differences
- Install missing dependencies manually if needed
- Verify Bluetooth hardware compatibility

### Future Compatibility

#### Planned Support
- Additional distributions based on user demand
- Alternative init systems (though systemd is standard)
- Container deployment options

#### Backward Compatibility
- Maintained for PAM API compatibility
- JSON format kept simple for easy parsing
- HMAC algorithm kept standard (SHA256)

### Verification Checklist

For each distribution, verify:
- [ ] Dependencies install successfully
- [ ] Build completes without errors
- [ ] Services start and run properly
- [ ] Bluetooth communication works
- [ ] Authentication flow completes
- [ ] PAM integration functions
- [ ] Security permissions are correct

### Troubleshooting

If compatibility issues arise:
1. Check the installer logs in `/tmp/tapin_install.log`
2. Verify all dependencies are installed
3. Confirm Bluetooth hardware and service are working
4. Review PAM configuration
5. Check service logs with `journalctl`

### Notes

The installer script automatically detects the distribution and installs the appropriate packages. This compatibility matrix ensures the TapIn system works reliably across different Linux environments while maintaining security and functionality.