# TapIn Flutter App and PAM Module Integration Guide

## Overview

This document explains how the TapIn Flutter mobile application and the Linux PAM module work together to provide passwordless authentication.

## System Architecture

The TapIn system consists of four main components that work together:

```
[Flutter Mobile App] ↔ [Bluetooth] ↔ [Linux System] ↔ [PAM Authentication]
       ↓                    ↓              ↓              ↓
Fingerprint Auth    Auth Request   Token Generation   User Login
```

## Integration Flow

### 1. Credential Setup Phase
1. User opens the TapIn Flutter app
2. User scans for Bluetooth devices and selects their Linux system
3. User enters Linux credentials (username/password) for that device
4. User authenticates with fingerprint to save credentials
5. Credentials are encrypted and stored with device-specific keys

### 2. Authentication Request Phase
1. User taps "TouchPass" in the Flutter app
2. User authenticates with fingerprint again
3. App retrieves stored credentials for the selected device
4. App creates an authentication request with HMAC signature:
   ```json
   {
     "username": "linux_username",
     "timestamp": "1234567890",
     "nonce": "random_nonce_value",
     "hmac": "hmac_signature"
   }
   ```

### 3. Bluetooth Communication Phase
1. Flutter app opens Bluetooth connection to the Linux system
2. Authentication request is sent via RFCOMM protocol
3. Bluetooth listener daemon receives the request
4. Request is forwarded to the helper daemon for validation

### 4. Token Generation Phase
1. Helper daemon validates the HMAC signature using the shared secret
2. Timestamp is checked to prevent delayed replay attacks
3. Nonce is verified to prevent immediate replay attacks
4. If validation passes, a temporary authentication token is created
5. Token is written to `/var/run/tapin_auth.token` with format: `username:token:expiry_timestamp`

### 5. PAM Authentication Phase
1. User attempts to log in via Linux login manager (GDM, SDDM, etc.)
2. PAM system calls the TapIn PAM module
3. PAM module checks for valid token file
4. Token is validated (expiry time, username match)
5. If valid, authentication succeeds without password requirement
6. Token is consumed (deleted) to prevent reuse
7. User session is unlocked

## Security Integration

### Shared Secret Synchronization
- The same shared secret must be configured in both the Flutter app and Linux system
- Located at `/etc/tapin/shared_secret` on Linux
- Used by both systems for HMAC signature generation and validation

### HMAC Signature Process
1. Flutter app generates HMAC using: `HMAC-SHA256(shared_secret, username:timestamp:nonce)`
2. Linux helper daemon recalculates HMAC with the same formula
3. Signatures are compared to validate the request authenticity

### Bluetooth Security
- Only pre-paired Bluetooth devices are accepted
- Communication is encrypted using Bluetooth security protocols
- Authentication requests are signed to prevent spoofing

## Configuration Requirements

### Flutter App Configuration
- Bluetooth permissions enabled
- Same shared secret as Linux system
- Proper device pairing with Linux system
- Fingerprint authentication capability

### Linux System Configuration
- Bluetooth adapter enabled and functional
- TapIn PAM module installed in `/lib/security/libtapin_pam.so`
- Helper and Bluetooth listener daemons running
- PAM configuration updated for login managers
- Shared secret configured in `/etc/tapin/shared_secret`

## Troubleshooting Integration Issues

### Common Issues
1. **Bluetooth connection fails**: Check device pairing and permissions
2. **HMAC validation fails**: Verify shared secrets match between devices
3. **PAM authentication doesn't trigger**: Check PAM configuration files
4. **Token file not found**: Verify helper daemon is running and creating tokens

### Debugging Steps
1. Check Bluetooth listener logs: `sudo journalctl -u tapin-bluetooth.service -f`
2. Check helper daemon logs: `sudo journalctl -u tapin-helper.service -f`
3. Verify shared secret: `sudo cat /etc/tapin/shared_secret`
4. Monitor token file: `ls -la /var/run/tapin_auth.token`

## Security Considerations

### Mobile App Security
- Never transmit raw fingerprint data
- Encrypt stored credentials using device-specific keys
- Require fingerprint authentication before any credential access
- Validate Bluetooth device identity before sending credentials

### Linux System Security
- Restrict permissions on sensitive files (600 for secrets and tokens)
- Validate all authentication requests before creating tokens
- Implement proper timeout and one-time use for tokens
- Monitor and log all authentication attempts

## Testing the Integration

### Pre-deployment Testing
1. Verify Bluetooth communication between devices
2. Test HMAC signature generation and validation
3. Validate token creation and consumption
4. Test PAM authentication flow

### Post-deployment Testing
1. Complete end-to-end authentication flow
2. Verify fallback to password authentication works
3. Test token expiration and cleanup
4. Confirm security measures are effective

This integration provides a secure, passwordless authentication system that leverages the security of mobile biometric authentication while maintaining the flexibility of Linux PAM authentication.