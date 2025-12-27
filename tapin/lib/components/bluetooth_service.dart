import 'dart:async';
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
}
