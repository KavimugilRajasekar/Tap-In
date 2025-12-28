import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BluetoothService {
  // Bluetooth adapter state
  static Stream<BluetoothAdapterState> get adapterState =>
      FlutterBluePlus.adapterState;

  // Scanning results
  static Stream<List<ScanResult>> get scanResults =>
      FlutterBluePlus.scanResults;

  // Connected devices
  static Stream<List<BluetoothDevice>> get connectedDevices async* {
    List<BluetoothDevice> devices = await FlutterBluePlus.connectedDevices;
    yield devices;
  }

  // Check if Bluetooth is enabled
  static Future<bool> isBluetoothEnabled() async {
    try {
      BluetoothAdapterState state = await FlutterBluePlus.adapterState.first;
      return state == BluetoothAdapterState.on;
    } catch (e) {
      print("Error checking Bluetooth state: $e");
      return false;
    }
  }

  // Enable Bluetooth
  static Future<void> enableBluetooth() async {
    try {
      await FlutterBluePlus.turnOn();
    } catch (e) {
      print("Error enabling Bluetooth: $e");
    }
  }

  // Disable Bluetooth
  static Future<void> disableBluetooth() async {
    try {
      await FlutterBluePlus.turnOff();
    } catch (e) {
      print("Error disabling Bluetooth: $e");
    }
  }

  // Start scanning for devices
  static Future<void> startScan() async {
    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    } catch (e) {
      print("Error starting scan: $e");
    }
  }

  // Stop scanning for devices
  static Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (e) {
      print("Error stopping scan: $e");
    }
  }

  // Connect to a device
  static Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect();
    } catch (e) {
      print("Error connecting to device: $e");
    }
  }

  // Disconnect from a device
  static Future<void> disconnectFromDevice(BluetoothDevice device) async {
    try {
      await device.disconnect();
    } catch (e) {
      print("Error disconnecting from device: $e");
    }
  }

  // Send data to a device via Bluetooth
  static Future<bool> writeDataToDevice(BluetoothDevice device, String data) async {
    try {
      // Connect to the device if not already connected
      if (!device.isConnected) {
        await device.connect(timeout: const Duration(seconds: 10));
      }
      
      // Get services
      List<BluetoothService> services = await device.discoverServices();
      
      // Look for the service used by TapIn (typically Serial Port Profile with UUID)
      BluetoothService? targetService;
      for (var service in services) {
        // Standard Serial Port Profile UUID
        if (service.uuid.toString().toLowerCase() == "00001101-0000-1000-8000-00805f9b34fb") {
          targetService = service;
          break;
        }
      }
      
      if (targetService == null) {
        print("TapIn service not found on device");
        return false;
      }
      
      // Find the characteristic to write to
      BluetoothCharacteristic? writeCharacteristic;
      for (var characteristic in targetService.characteristics) {
        // Check if this characteristic has write property
        if (characteristic.properties.write || characteristic.properties.writeWithoutResponse) {
          writeCharacteristic = characteristic;
          break;
        }
      }
      
      if (writeCharacteristic == null) {
        print("No writable characteristic found");
        return false;
      }
      
      // Write the data to the characteristic
      await writeCharacteristic.write(utf8.encode(data));
      print("Data sent successfully: $data");
      return true;
    } catch (e) {
      print("Error writing data to device: $e");
      return false;
    }
  }
}