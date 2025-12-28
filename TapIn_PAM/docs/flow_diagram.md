# TapIn Authentication Flow

## Complete Authentication Process

```
┌─────────────────┐    Bluetooth    ┌──────────────────────┐
│                 │   Connection    │                      │
│  TapIn Flutter  │ ──────────────▶ │ Bluetooth Listener   │
│  Mobile App     │                 │  Daemon              │
│                 │                 │                      │
└─────────────────┘                 └──────────────────────┘
        │                                      │
        │                                      │ JSON Auth Request
        │                                      │ (username, timestamp, nonce, hmac)
        │                                      ▼
        │                              ┌──────────────────────┐
        │                              │                      │
        │                              │  Helper Daemon       │
        │                              │                      │
        │                              └──────────────────────┘
        │                                      │
        │                                      │ Validate HMAC
        │                                      │ Check Timestamp
        │                                      │ Verify Nonce
        │                                      ▼
        │                              ┌──────────────────────┐
        │                              │                      │
        │                              │ Generate Auth Token  │
        │                              │ Write to:            │
        │                              │ /var/run/tapin_auth.token
        │                              │                      │
        │                              └──────────────────────┘
        │                                      │
        │                                      │
        ▼                                      ▼
┌─────────────────┐    PAM Auth    ┌──────────────────────┐
│                 │   Request      │                      │
│  Linux Login    │ ────────────▶  │  PAM Module          │
│  Manager        │                │  (libtapin_pam.so)   │
│  (GDM, SDDM,    │                │                      │
│   etc.)         │ ◀──────────────┤                      │
└─────────────────┘   Auth Result  └──────────────────────┘
        │                                      │
        │                                      │ Read token file
        │                                      │ Validate token
        │                                      │ Check expiry
        │                                      │ Match username
        │                                      │ Consume token
        ▼                                      ▼
┌─────────────────┐                    ┌──────────────────────┐
│                 │                    │                      │
│  User Session   │ ◀───────────────── │ Authentication       │
│  Unlocked       │   Grant Access     │ Success              │
│                 │                    │                      │
└─────────────────┘                    └──────────────────────┘
```

## Detailed Steps

### Mobile App Phase
1. User opens TapIn Flutter app
2. User selects a paired Bluetooth device
3. User enters credentials (username/password) for that device
4. User taps "Save Credentials" and authenticates with fingerprint
5. Credentials are encrypted and stored with device-specific keys
6. User taps "TouchPass" and authenticates with fingerprint again
7. App retrieves stored credentials and creates authentication request
8. Authentication request is sent via Bluetooth to Linux system

### Authentication Request Format
```json
{
  "username": "linux_username",
  "timestamp": "1234567890",
  "nonce": "random_nonce_value",
  "hmac": "hmac_signature"
}
```

### Linux System Phase
1. Bluetooth listener receives authentication request
2. Request is forwarded to helper daemon
3. Helper daemon validates HMAC signature
4. Helper daemon checks timestamp validity
5. Helper daemon verifies nonce hasn't been used (replay prevention)
6. If validation passes, a temporary token is created
7. Token is written to `/var/run/tapin_auth.token`
8. Token format: `username:random_token:expiry_timestamp`

### PAM Authentication Phase
1. User attempts to log in via login manager
2. PAM system calls TapIn PAM module
3. PAM module checks for valid token file
4. Token is validated (expiry, username match)
5. If valid, authentication succeeds without password
6. Token is consumed (deleted) to prevent reuse
7. User session is unlocked

## Security Features

### Cryptographic Security
- **HMAC Validation**: All requests are signed with HMAC-SHA256
- **Timestamp Checking**: Prevents delayed replay attacks
- **Nonce Verification**: Prevents immediate replay attacks
- **Token Expiration**: Tokens expire after 20 seconds
- **One-Time Use**: Tokens are consumed after single use

### System Security
- **Restricted Permissions**: Token file readable only by root
- **Bluetooth Pairing**: Only paired devices accepted
- **Secure Storage**: Credentials encrypted on mobile device
- **Biometric Verification**: Authentication required on mobile device

## Configuration Files

### PAM Configuration (`/etc/pam.d/tapin`)
```
auth    sufficient    pam_tapin.so
account required      pam_tapin.so
```

### Shared Secret (`/etc/tapin/shared_secret`)
- 256-bit secret key for HMAC generation
- Readable only by root
- Used by both mobile app and helper daemon

## System Services

### tapin-helper.service
- Validates authentication requests
- Creates temporary authentication tokens
- Runs with root privileges

### tapin-bluetooth.service
- Listens for Bluetooth connections
- Receives authentication requests from mobile app
- Forwards requests to helper daemon
- Runs with root privileges