import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'components/bluetooth_service.dart';
import 'components/secure_storage.dart';
import 'components/fingerprint_auth.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as blue_plus_lib;

class TypingText extends StatefulWidget {
  final String text;
  final TextStyle? textStyle;
  final Duration speed;

  const TypingText({
    super.key,
    required this.text,
    this.textStyle,
    this.speed = const Duration(milliseconds: 30),
  });

  @override
  State<TypingText> createState() => _TypingTextState();
}

class _TypingTextState extends State<TypingText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _typingAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(
        milliseconds: widget.text.length * widget.speed.inMilliseconds,
      ),
      vsync: this,
    );

    _typingAnimation = StepTween(
      begin: 0,
      end: widget.text.length,
    ).animate(_controller);

    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant TypingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _controller.duration = Duration(
        milliseconds: widget.text.length * widget.speed.inMilliseconds,
      );
      _typingAnimation = StepTween(
        begin: 0,
        end: widget.text.length,
      ).animate(_controller);
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _typingAnimation,
      builder: (context, child) {
        return Text(
          widget.text.substring(0, _typingAnimation.value),
          style: widget.textStyle,
        );
      },
    );
  }
}

class TapInScreen extends StatefulWidget {
  const TapInScreen({super.key});

  @override
  State<TapInScreen> createState() => _TapInScreenState();
}

class _TapInScreenState extends State<TapInScreen>
    with TickerProviderStateMixin {
  // Track expanded state for all labels
  final List<bool> _expandedStates = [false, false, false, false, false];

  // Track scanned Bluetooth devices
  List<blue_plus_lib.ScanResult> _scannedDevices = [];
  bool _isScanning = false;
  StreamSubscription<List<blue_plus_lib.ScanResult>>? _scanSubscription;

  // Track selected device for credentials
  blue_plus_lib.ScanResult? _selectedDeviceForCredentials;

  // Credential form controllers
  final TextEditingController _deviceNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Credential form states
  String _deviceNameError = '';
  String _usernameError = '';
  String _passwordError = '';
  bool _isFingerprintAuthEnabled = false;

  void _toggleExpanded(int index) async {
    // If trying to expand the Credential section (index 3) without a selected device, prevent expansion
    if (index == 3 &&
        _selectedDeviceForCredentials == null &&
        _expandedStates[index] == false) {
      // Don't allow expansion if no device is selected
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select a device from Bluetooth scan results first',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // If trying to expand the TouchPass section (index 4), check if credentials exist for the selected device
    if (index == 4 && _expandedStates[index] == false) {
      if (_selectedDeviceForCredentials == null) {
        // No device selected
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please select a device from Bluetooth scan and save credentials first',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      } else {
        // Check if credentials exist for the selected device
        String deviceKey = _selectedDeviceForCredentials!.device.id.id;
        String? deviceName = await SecureStorage.readSecureData(
          '${deviceKey}_deviceName',
        );
        String? username = await SecureStorage.readSecureData(
          '${deviceKey}_username',
        );
        String? password = await SecureStorage.readSecureData(
          '${deviceKey}_password',
        );

        if (deviceName == null || username == null || password == null) {
          // No credentials found for this device
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No credentials found for this device. Please save credentials first.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
      }
    }

    setState(() {
      // If the clicked section is currently expanded, just collapse it
      if (_expandedStates[index]) {
        _expandedStates[index] = false;
      } else {
        // If the clicked section is collapsed, collapse all sections and then expand this one
        for (int i = 0; i < _expandedStates.length; i++) {
          _expandedStates[i] = false;
        }
        _expandedStates[index] = true;
      }
    });

    // If expanding the Bluetooth scan section, start scanning
    if (index == 2 && _expandedStates[index]) {
      // Index 2 is BluetoothScan
      _startBluetoothScan();
    } else if (index == 2 && !_expandedStates[index]) {
      // If collapsing, stop scanning
      _stopBluetoothScan();
    }
  }

  void _startBluetoothScan() async {
    // Clear previous scan results
    setState(() {
      _scannedDevices = [];
      _isScanning = true;
    });

    try {
      // Check if Bluetooth is enabled
      bool isBluetoothEnabled = await BluetoothService.isBluetoothEnabled();
      if (!isBluetoothEnabled) {
        // Try to enable Bluetooth
        await BluetoothService.enableBluetooth();
        await Future.delayed(
          Duration(seconds: 2),
        ); // Wait for Bluetooth to enable
      }

      // Start scanning
      await BluetoothService.startScan();

      // Listen to scan results
      _scanSubscription = blue_plus_lib.FlutterBluePlus.scanResults.listen((
        results,
      ) {
        setState(() {
          _scannedDevices = results;
        });
      });
    } catch (e) {
      print('Error starting Bluetooth scan: $e');
      setState(() {
        _isScanning = false;
      });
    }
  }

  void _stopBluetoothScan() {
    try {
      BluetoothService.stopScan();
      _scanSubscription?.cancel();
      setState(() {
        _isScanning = false;
      });
    } catch (e) {
      print('Error stopping Bluetooth scan: $e');
    }
  }

  void _selectDeviceForCredentials(blue_plus_lib.ScanResult device) async {
    setState(() {
      _selectedDeviceForCredentials = device;

      // Set the selected device name in the controller
      _deviceNameController.text = device.device.name.isEmpty
          ? 'Unknown Device (${device.device.id.toString().split('-').last.toUpperCase()})'
          : device.device.name;
    });

    // Load the stored fingerprint authentication state if it exists
    String deviceKey = device.device.id.id;
    String? storedFingerprintAuth = await SecureStorage.readSecureData(
      '${deviceKey}_fingerprintAuth',
    );

    setState(() {
      // Set the fingerprint auth state based on stored value
      _isFingerprintAuthEnabled = storedFingerprintAuth == 'true';

      // Expand the credential section
      for (int i = 0; i < _expandedStates.length; i++) {
        _expandedStates[i] = false;
      }
      _expandedStates[3] = true; // Index 3 is Credential section
    });
  }

  @override
  void dispose() {
    _stopBluetoothScan();
    // Dispose of text controllers
    _deviceNameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Widget _buildCredentialForm() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          const Text(
            'Device Credentials',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'PlaywriteUSModern',
            ),
          ),
          const SizedBox(height: 16.0),

          // Selected device info
          if (_selectedDeviceForCredentials != null)
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                border: Border.all(color: Colors.blue.shade200),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selected Device: ${_selectedDeviceForCredentials!.device.name.isEmpty ? 'Unknown Device (${_selectedDeviceForCredentials!.device.id.toString().split('-').last.toUpperCase()})' : _selectedDeviceForCredentials!.device.name}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'PlaywriteUSModern',
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    'MAC: ${_selectedDeviceForCredentials!.device.id.id}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontFamily: 'PlaywriteUSModern',
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16.0),

          // Device Name Field
          const Text(
            'Device Name',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              fontFamily: 'PlaywriteUSModern',
            ),
          ),
          const SizedBox(height: 8.0),
          TextField(
            controller: _deviceNameController,
            decoration: InputDecoration(
              hintText: 'Enter device name',
              border: const OutlineInputBorder(),
              errorText: _deviceNameError.isEmpty ? null : _deviceNameError,
            ),
          ),

          const SizedBox(height: 16.0),

          // Username Field
          const Text(
            'Username',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              fontFamily: 'PlaywriteUSModern',
            ),
          ),
          const SizedBox(height: 8.0),
          TextField(
            controller: _usernameController,
            decoration: InputDecoration(
              hintText: 'Enter username',
              border: const OutlineInputBorder(),
              errorText: _usernameError.isEmpty ? null : _usernameError,
            ),
          ),

          const SizedBox(height: 16.0),

          // Password Field
          const Text(
            'Password',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              fontFamily: 'PlaywriteUSModern',
            ),
          ),
          const SizedBox(height: 8.0),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: InputDecoration(
              hintText: 'Enter password',
              border: const OutlineInputBorder(),
              errorText: _passwordError.isEmpty ? null : _passwordError,
            ),
          ),

          const SizedBox(height: 20.0),

          // Fingerprint Authentication Button
          Center(
            child: Column(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.fingerprint,
                    size: 60,
                    color: _isFingerprintAuthEnabled
                        ? Colors.green
                        : Colors.grey,
                  ),
                  onPressed: () {
                    _enableFingerprintAuth();
                  },
                ),
                const Text(
                  'Enable Fingerprint Auth',
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: 'PlaywriteUSModern',
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20.0),

          // Save Credentials Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                _saveCredentials();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16.0),
              ),
              child: const Text(
                'Save Credentials',
                style: TextStyle(fontSize: 16, fontFamily: 'PlaywriteUSModern'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTouchPassSection() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Title
          const Text(
            'TouchPass Authentication',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'PlaywriteUSModern',
            ),
          ),
          const SizedBox(height: 24.0),

          // Description
          Text(
            'Authenticate with your fingerprint to send credentials to a Bluetooth device',
            style: const TextStyle(
              fontSize: 16,
              fontFamily: 'PlaywriteUSModern',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32.0),

          // Fingerprint Icon
          Center(
            child: GestureDetector(
              onTap: () {
                _authenticateAndSendCredentials();
              },
              child: Column(
                children: [
                  Icon(Icons.fingerprint, size: 100, color: Colors.blueGrey),
                  const SizedBox(height: 16.0),
                  const Text(
                    'Tap to Authenticate',
                    style: TextStyle(
                      fontSize: 16,
                      fontFamily: 'PlaywriteUSModern',
                      color: Colors.blueGrey,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24.0),

          // Status message
          const Text(
            'Place your finger on the sensor to authenticate and send credentials',
            style: TextStyle(
              fontSize: 14,
              fontFamily: 'PlaywriteUSModern',
              color: Colors.grey,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _enableFingerprintAuth() async {
    // First check if device supports biometric authentication
    bool canCheckBiometrics = await FingerprintAuth.hasBiometrics();

    if (!canCheckBiometrics) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Biometric authentication is not available on this device',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Attempt to authenticate with fingerprint
    bool isAuthenticated = await FingerprintAuth.authenticate();

    if (isAuthenticated) {
      setState(() {
        _isFingerprintAuthEnabled = true;
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fingerprint verified successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      // Show authentication failed message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fingerprint authentication failed'),
          backgroundColor: Colors.red,
        ),
      );

      // Keep the state as it was before the attempt
      // If it was already enabled, keep it enabled, otherwise remain disabled
    }
  }

  void _authenticateAndSendCredentials() async {
    // First check if we have a selected device
    if (_selectedDeviceForCredentials == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No device selected. Please select a device from Bluetooth scan first.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // First check if device supports biometric authentication
    bool canCheckBiometrics = await FingerprintAuth.hasBiometrics();

    if (!canCheckBiometrics) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Biometric authentication is not available on this device',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Attempt to authenticate with fingerprint
    bool isAuthenticated = await FingerprintAuth.authenticate();

    if (isAuthenticated) {
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Fingerprint verified successfully! Now sending authentication request to device...',
          ),
          backgroundColor: Colors.green,
        ),
      );

      // Retrieve stored credentials for the selected device
      String deviceKey = _selectedDeviceForCredentials!.device.id.id;
      String? deviceName = await SecureStorage.readSecureData(
        '${deviceKey}_deviceName',
      );
      String? username = await SecureStorage.readSecureData(
        '${deviceKey}_username',
      );
      String? password = await SecureStorage.readSecureData(
        '${deviceKey}_password',
      );

      // Check if credentials exist for this device
      if (deviceName != null && username != null && password != null) {
        // Create authentication request with HMAC signature
        String authRequest = await _createAuthRequest(username);
        
        // Send the authentication request to the Linux daemon via Bluetooth
        bool success = await BluetoothService.writeDataToDevice(
          _selectedDeviceForCredentials!.device,
          authRequest,
        );
        
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Authentication request sent successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to send authentication request'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        // No credentials found for this device
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No credentials found for ${_selectedDeviceForCredentials!.device.name.isEmpty ? 'this device' : _selectedDeviceForCredentials!.device.name}. Please save credentials first.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } else {
      // Show authentication failed message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fingerprint authentication failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _saveCredentials() async {
    // Reset errors
    setState(() {
      _deviceNameError = '';
      _usernameError = '';
      _passwordError = '';
    });

    bool hasError = false;

    // Validate inputs
    if (_deviceNameController.text.trim().isEmpty) {
      setState(() {
        _deviceNameError = 'Device name is required';
      });
      hasError = true;
    }

    if (_usernameController.text.trim().isEmpty) {
      setState(() {
        _usernameError = 'Username is required';
      });
      hasError = true;
    }

    if (_passwordController.text.trim().isEmpty) {
      setState(() {
        _passwordError = 'Password is required';
      });
      hasError = true;
    }

    if (hasError) return;

    // Require fingerprint authentication before saving credentials
    bool canCheckBiometrics = await FingerprintAuth.hasBiometrics();

    if (!canCheckBiometrics) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Biometric authentication is not available on this device. Fingerprint scan is required to save credentials.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Attempt to authenticate with fingerprint
    bool isAuthenticated = await FingerprintAuth.authenticate();

    if (!isAuthenticated) {
      // Show authentication failed message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Fingerprint authentication failed. Credentials not saved.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Generate a unique key for the credentials based on device ID
      String deviceKey = _selectedDeviceForCredentials!.device.id.id;

      // Store credentials using secure storage
      await SecureStorage.writeSecureData(
        '${deviceKey}_deviceName',
        _deviceNameController.text.trim(),
      );
      await SecureStorage.writeSecureData(
        '${deviceKey}_username',
        _usernameController.text.trim(),
      );
      await SecureStorage.writeSecureData(
        '${deviceKey}_password',
        _passwordController.text.trim(),
      );

      // Store fingerprint auth preference
      await SecureStorage.writeSecureData(
        '${deviceKey}_fingerprintAuth',
        _isFingerprintAuthEnabled.toString(),
      );

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Credentials saved successfully after fingerprint verification!',
          ),
          backgroundColor: Colors.green,
        ),
      );

      // Optionally, clear the form after saving
      setState(() {
        _passwordController.clear();
        _usernameController.clear();
        // Don't clear device name as it's tied to the selected device
      });
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving credentials: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Create authentication request with HMAC signature
  Future<String> _createAuthRequest(String username) async {
    // Get the shared secret from secure storage or use a default value
    // In a real implementation, the shared secret should be configured in the app
    String sharedSecret = await SecureStorage.readSecureData('shared_secret') ?? 'default_secret';
    
    // Create timestamp and nonce
    int timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    String nonce = _generateNonce();
    
    // Create the data to be signed: username:timestamp:nonce
    String dataToSign = '$username:$timestamp:$nonce';
    
    // Generate HMAC signature
    String hmac = await _generateHmac(dataToSign, sharedSecret);
    
    // Create JSON authentication request
    Map<String, String> authRequest = {
      'username': username,
      'timestamp': timestamp.toString(),
      'nonce': nonce,
      'hmac': hmac,
    };
    
    return jsonEncode(authRequest);
  }
  
  // Generate a random nonce
  String _generateNonce() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(16, (index) => chars[random.nextInt(chars.length)]).join();
  }
  
  // Generate HMAC signature
  Future<String> _generateHmac(String data, String secret) async {
    // Create the HMAC-SHA256 hash
    var bytes = utf8.encode(data);
    var secretBytes = utf8.encode(secret);
    var hmac = Hmac(sha256, secretBytes);
    var digest = hmac.convert(bytes);
    return digest.toString();
  }

  Widget _buildExpandableLabeledBox(
    int index,
    String title,
    String description,
  ) {
    bool isExpanded = _expandedStates[index];
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onTap: () => _toggleExpanded(index),
            child: Container(
              padding: const EdgeInsets.all(16.0),
              child: Align(
                alignment: Alignment.center,
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Comfortaa',
                  ),
                ),
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: SizeTransition(sizeFactor: animation, child: child),
              );
            },
            child: isExpanded
                ? Container(
                    key: const ValueKey<bool>(true),
                    padding: const EdgeInsets.fromLTRB(
                      0.0,
                      0.0,
                      0.0,
                      16.0,
                    ), // Remove side padding
                    child:
                        index ==
                            2 // BluetoothScan section
                        ? Container(
                            width: double.infinity,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Show scanning status
                                if (_isScanning)
                                  const Padding(
                                    padding: EdgeInsets.only(
                                      bottom: 12.0,
                                      left: 16.0,
                                      right: 16.0,
                                    ),
                                    child: Text(
                                      'Scanning for devices...',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontFamily: 'PlaywriteUSModern',
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                // Show found devices
                                if (_scannedDevices.isNotEmpty)
                                  Padding(
                                    padding: EdgeInsets.only(
                                      left: 16.0,
                                      right: 16.0,
                                    ),
                                    child: Text(
                                      'Found ${_scannedDevices.length} device(s):',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'PlaywriteUSModern',
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 8.0),
                                // List of devices
                                ..._scannedDevices.map((device) {
                                  String deviceName = device.device.name;
                                  // If device name is empty, try to use the device ID as a fallback
                                  if (deviceName.isEmpty) {
                                    // Extract a readable name from the device ID if possible
                                    deviceName =
                                        'Unknown Device (${device.device.id.toString().split('-').last.toUpperCase()})';
                                  }
                                  return Container(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 8.0,
                                      vertical: 8.0,
                                    ),
                                    padding: const EdgeInsets.all(12.0),
                                    width: double
                                        .infinity, // Full width to eliminate side margins
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                      ),
                                      borderRadius: BorderRadius.circular(6.0),
                                      color: Colors.grey.shade50,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        GestureDetector(
                                          onTap: () {
                                            _selectDeviceForCredentials(device);
                                          },
                                          child: Text(
                                            'Name: $deviceName',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                              fontFamily: 'PlaywriteUSModern',
                                              decoration:
                                                  TextDecoration.underline,
                                              color: Colors.blue,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 4.0),
                                        Text(
                                          'MAC: ${device.device.id.id}',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontFamily: 'PlaywriteUSModern',
                                            color: Colors.grey,
                                          ),
                                        ),
                                        const SizedBox(height: 4.0),
                                        Text(
                                          'RSSI: ${device.rssi} dBm',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontFamily: 'PlaywriteUSModern',
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          )
                        : index ==
                              3 // Credential section
                        ? _buildCredentialForm()
                        : index ==
                              4 // TouchPass section
                        ? _buildTouchPassSection()
                        : TypingText(
                            text: description,
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontFamily: 'PlaywriteUSModern',
                            ),
                          ),
                  )
                : const SizedBox.shrink(key: ValueKey<bool>(false)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            _buildExpandableLabeledBox(
              0, // index for _expandedStates
              'TapIn',
              'Welcome to TapIn! This is your personalized space where you can access all your important information and features. Tap on any label below to expand and view more details.',
            ),
            const SizedBox(height: 20),
            _buildExpandableLabeledBox(
              1, // index for _expandedStates
              'Description',
              'This is the second label description. It provides information about the second item.',
            ),
            const SizedBox(height: 20),
            _buildExpandableLabeledBox(
              2, // index for _expandedStates
              'BluetoothScan',
              'This is the third label description. It provides information about the third item.',
            ),
            const SizedBox(height: 20),
            _buildExpandableLabeledBox(
              3, // index for _expandedStates
              'Credential',
              'This is the fourth label description. It provides information about the fourth item.',
            ),
            const SizedBox(height: 20),
            _buildExpandableLabeledBox(
              4, // index for _expandedStates
              'TouchPass',
              'This is the fifth label description. It provides information about the fifth item.',
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
