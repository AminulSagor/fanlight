import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'esp_control_controller.dart';

class ESPControlView extends StatelessWidget {
  ESPControlView({super.key});
  final controller = Get.put(ESPControlController());

  Widget buildControlCard({
    required IconData icon,
    required String label,
    required VoidCallback onTurnOn,
    required VoidCallback onTurnOff,
  }) {
    return Container(
      padding: EdgeInsets.all(16.w),
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20.r),
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 32.sp),
            SizedBox(width: 8.w),
            Text(label, style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
          ]),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    backgroundColor: Colors.blue,
                  ),
                  onPressed: onTurnOn,
                  child: Text("Turn On", style: TextStyle(fontSize: 16.sp)),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    backgroundColor: Colors.grey[300],
                  ),
                  onPressed: onTurnOff,
                  child: Text("Turn Off", style: TextStyle(fontSize: 16.sp, color: Colors.black)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildScheduleCard(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20.r),
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Schedule", style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
          SizedBox(height: 12.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 14.h),
                backgroundColor: Colors.grey[200],
              ),
              onPressed: () async {
                final selectedDevice = await showDialog<String>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text("Select Device"),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          title: Text("Fan"),
                          onTap: () => Navigator.pop(context, "Fan"),
                        ),
                        ListTile(
                          title: Text("Light"),
                          onTap: () => Navigator.pop(context, "Light"),
                        ),
                      ],
                    ),
                  ),
                );

                if (selectedDevice != null) {
                  final isRecurring = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text("Repeat Daily?"),
                      content: Text("Do you want this to repeat every day?"),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text("No"),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: Text("Yes"),
                        ),
                      ],
                    ),
                  );

                  final selectedTime = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );

                  if (selectedTime != null) {
                    final now = DateTime.now();
                    DateTime? selectedDate;

                    if (isRecurring == true) {
                      selectedDate = now;
                    } else {
                      selectedDate = await showDatePicker(
                        context: context,
                        initialDate: now,
                        firstDate: now,
                        lastDate: DateTime(2100),
                      );
                    }

                    if (selectedDate != null) {
                      final combined = DateTime(
                        selectedDate.year,
                        selectedDate.month,
                        selectedDate.day,
                        selectedTime.hour,
                        selectedTime.minute,
                      );
                      await controller.addSchedule(selectedDevice, combined, isRecurring ?? false);
                    }
                  }
                }
              },
              child: Text("Set Schedule", style: TextStyle(fontSize: 16.sp, color: Colors.black)),
            ),
          ),
          SizedBox(height: 16.h),
          Obx(() => controller.schedules.isEmpty
              ? Text("No schedules set.", style: TextStyle(fontSize: 14.sp))
              : ListView.separated(
            physics: NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: controller.schedules.length,
            separatorBuilder: (_, __) => Divider(),
            itemBuilder: (_, index) {
              final schedule = controller.schedules[index];
              final time = DateTime.parse(schedule["time"]);
              final recurring = schedule["recurring"] == true ? " (Daily)" : "";
              final period = time.hour >= 12 ? "PM" : "AM";
              final hour12 = time.hour % 12 == 0 ? 12 : time.hour % 12;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.schedule, color: Colors.blueAccent),
                title: Text("${schedule["device"]} Schedule$recurring",
                    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w500)),
                subtitle: Text(
                  "${time.day}/${time.month}/${time.year} - ${hour12.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} $period",
                  style: TextStyle(fontSize: 14.sp),
                ),
                trailing: IconButton(
                  icon: Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: () async {
                    controller.schedules.removeAt(index);
                    final prefs = await SharedPreferences.getInstance();
                    prefs.setString('schedules', jsonEncode(controller.schedules));
                  },
                ),
              );
            },
          )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text("Home", style: TextStyle(fontSize: 20.sp)),
        centerTitle: true,
        elevation: 0,
      ),
      body: Obx(() {
        if (controller.isDiscovering.value) {
          return Center(child: CircularProgressIndicator());
        } else if (controller.discoveredIp.isEmpty) {
          return Center(child: Text("ESP32 not found", style: TextStyle(fontSize: 16.sp)));
        } else {
          return Padding(
            padding: EdgeInsets.all(16.w),
            child: ListView(
              children: [
                Text("ESP32 IP: ${controller.discoveredIp}", style: TextStyle(fontSize: 14.sp)),
                SizedBox(height: 20.h),
                buildControlCard(
                  icon: Icons.toys,
                  label: "Fan",
                  onTurnOn: () => controller.espService.sendCommand("fan/on"),
                  onTurnOff: () => controller.espService.sendCommand("fan/off"),
                ),
                buildControlCard(
                  icon: Icons.lightbulb_outline,
                  label: "Light",
                  onTurnOn: () => controller.espService.sendCommand("light/on"),
                  onTurnOff: () => controller.espService.sendCommand("light/off"),
                ),
                buildScheduleCard(context),
              ],
            ),
          );
        }
      }),
    );
  }
}
