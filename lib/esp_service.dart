import 'package:http/http.dart' as http;

class ESPService {
  String? ip;

  void setIp(String ipAddress) {
    ip = ipAddress;
  }

  Future<void> sendCommand(String command) async {
    if (ip == null) throw Exception("ESP32 IP not set");
    final url = Uri.parse('http://$ip/$command');
    await http.get(url);
  }
}
