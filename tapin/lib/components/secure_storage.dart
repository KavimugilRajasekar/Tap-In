import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  // Create storage instance
  static const _storage = FlutterSecureStorage();

  // Write secure data
  static Future<void> writeSecureData(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      print("Error writing secure data: $e");
    }
  }

  // Read secure data
  static Future<String?> readSecureData(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      print("Error reading secure data: $e");
      return null;
    }
  }

  // Delete secure data
  static Future<void> deleteSecureData(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      print("Error deleting secure data: $e");
    }
  }

  // Delete all secure data
  static Future<void> deleteAllSecureData() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      print("Error deleting all secure data: $e");
    }
  }

  // Check if key exists
  static Future<bool> containsKey(String key) async {
    try {
      return await _storage.containsKey(key: key);
    } catch (e) {
      print("Error checking if key exists: $e");
      return false;
    }
  }
}
