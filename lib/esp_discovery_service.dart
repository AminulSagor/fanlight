import 'package:flutter/services.dart';

class NativeESPDiscovery {
  static const platform = MethodChannel('com.example.fan_light/mdns');

  static Future<String?> discoverESP32() async {
    try {
      final result = await platform.invokeMethod<String>('discoverESP32');
      return result;
    } catch (e) {
      print("❌ Native mDNS discovery failed: $e");
      return null;
    }
  }
}
