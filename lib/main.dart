import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:workmanager/workmanager.dart';
import 'dart:convert';

import 'esp_control_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: true);

  await Workmanager().registerPeriodicTask(
    "uniqueTaskId",
    "scheduleCheck",
    frequency: const Duration(minutes: 15), // Android min is 15
    initialDelay: const Duration(seconds: 10),
    constraints: Constraints(
      networkType: NetworkType.connected,
    ),
  );

  runApp(const MyApp());
}

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    await _handleAlarmLogic();
    return Future.value(true);
  });
}

Future<void> _handleAlarmLogic() async {
  final prefs = await SharedPreferences.getInstance();
  final data = prefs.getString('schedules');
  if (data != null) {
    final schedules = List<Map<String, dynamic>>.from(jsonDecode(data));
    final now = DateTime.now();
    print("⏰ alarmCallback running at $now");

    final nowTruncated = DateTime(now.year, now.month, now.day, now.hour, now.minute);

    for (final schedule in schedules) {
      final time = DateTime.parse(schedule["time"]);
      final scheduleTruncated = DateTime(time.year, time.month, time.day, time.hour, time.minute);

      final isRecurring = schedule["recurring"] == true;
      final matchesOnce = scheduleTruncated == nowTruncated;
      final matchesRecurring = isRecurring && time.hour == now.hour && time.minute == now.minute;

      print("🔍 Checking: $scheduleTruncated vs $nowTruncated");

      if (matchesOnce || matchesRecurring) {
        final device = schedule["device"];
        final command = device == "Fan" ? "fan/on" : "light/on";

        final ip = prefs.getString('last_ip');
        if (ip != null) {
          final url = Uri.parse('http://$ip/$command');
          try {
            await http.get(url);
            print("✅ Triggered $command at $now");
          } catch (e) {
            print("❌ Failed to send $command: $e");
          }
        }
      }
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      builder: (context, child) {
        return MaterialApp(
          title: 'ESP32 Switch',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
            useMaterial3: true,
          ),
          home: ESPControlView(),
        );
      },
    );
  }
}
