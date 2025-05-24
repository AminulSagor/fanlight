import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'esp_service.dart';
import 'esp_discovery_service.dart';

class ESPControlController extends GetxController {
  final espService = ESPService();
  final discovery = NativeESPDiscovery();
  var isDiscovering = false.obs;
  var discoveredIp = ''.obs;
  RxList<Map<String, dynamic>> schedules = <Map<String, dynamic>>[].obs;

  @override
  void onInit() {
    super.onInit();
    requestPermissionAndDiscover();
    loadSchedules();
  }

  Future<void> requestPermissionAndDiscover() async {
    final status = await Permission.location.request();

    if (status.isGranted) {
      await discoverAndConnect();
    } else {
      print("\u274c Location permission denied");
    }
  }

  Future<void> discoverAndConnect() async {
    isDiscovering.value = true;
    final ipPort = await NativeESPDiscovery.discoverESP32();
    final prefs = await SharedPreferences.getInstance();

    if (ipPort != null) {
      final ip = ipPort.split(':').first;
      espService.setIp(ip);
      discoveredIp.value = ip;
      prefs.setString('last_ip', ip); // ✅ Save discovered IP
    } else {
      final fallbackIp = '192.168.0.109';
      print("⚠️ Using fallback IP: $fallbackIp");
      espService.setIp(fallbackIp);
      discoveredIp.value = fallbackIp;
      prefs.setString('last_ip', fallbackIp); // ✅ Save fallback IP
    }

    isDiscovering.value = false;
  }


  void turnOn() => espService.sendCommand("on");
  void turnOff() => espService.sendCommand("off");

  Future<void> addSchedule(String device, DateTime time, bool isRecurring) async {
    final newSchedule = {
      "device": device,
      "time": time.toIso8601String(),
      "recurring": isRecurring,
    };
    schedules.add(newSchedule);
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('schedules', jsonEncode(schedules));
  }


  Future<void> loadSchedules() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('schedules');
    if (data != null) {
      schedules.value = List<Map<String, dynamic>>.from(jsonDecode(data));
    }
  }
}
