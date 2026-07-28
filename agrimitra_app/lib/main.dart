import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'chat_screen.dart';
import 'config.dart';
import 'login_screen.dart';
import 'calendar_screen.dart';
import 'theme.dart';
import 'widgets/moisture_gauge.dart';

void main() {
  runApp(const AgriMitraApp());
}

class AgriMitraApp extends StatelessWidget {
  const AgriMitraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AgriMitra',
      theme: AgriMitraTheme.theme,
      home: const LoginScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? sensorData;
  Map<String, dynamic>? irrigationData;
  Map<String, dynamic>? cropData;
  List<dynamic> history = [];
  List<dynamic> alerts = [];
  String status = "Loading...";
  Timer? timer;
  String? farmerName;

  final String baseUrl = "${Config.apiBaseUrl}/api/sensors/esp32-01";
  final String irrigationUrl = "${Config.apiBaseUrl}/api/irrigation/esp32-01/recommendation";
  final String cropUrl = "${Config.apiBaseUrl}/api/crop/esp32-01/recommend";
  final String alertsUrl = "${Config.apiBaseUrl}/api/alerts/esp32-01";

  @override
  void initState() {
    super.initState();
    loadFarmerName();
    fetchData();
    timer = Timer.periodic(const Duration(seconds: 10), (_) => fetchData());
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> loadFarmerName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      farmerName = prefs.getString('farmerName');
    });
  }

  Future<Map<String, String>> getAuthHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    return {'Authorization': 'Bearer $token'};
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  Future<void> fetchData() async {
    try {
      final headers = await getAuthHeaders();

      final latestResponse = await http.get(Uri.parse('$baseUrl/latest'), headers: headers);
      final historyResponse = await http.get(Uri.parse('$baseUrl/history'), headers: headers);
      final irrigationResponse = await http.get(Uri.parse(irrigationUrl), headers: headers);
      final cropResponse = await http.get(Uri.parse(cropUrl), headers: headers);
      final alertsResponse = await http.get(Uri.parse(alertsUrl), headers: headers);

      if (latestResponse.statusCode == 200) {
        setState(() {
          sensorData = jsonDecode(latestResponse.body);
          status = "Loaded";
        });
      } else if (latestResponse.statusCode == 401) {
        logout();
      } else {
        setState(() => status = "No data found (status ${latestResponse.statusCode})");
      }

      if (historyResponse.statusCode == 200) {
        setState(() {
          history = jsonDecode(historyResponse.body);
        });
      }

      if (irrigationResponse.statusCode == 200) {
        setState(() {
          irrigationData = jsonDecode(irrigationResponse.body);
        });
      }

      if (cropResponse.statusCode == 200) {
        setState(() {
          cropData = jsonDecode(cropResponse.body);
        });
      }

      if (alertsResponse.statusCode == 200) {
        setState(() {
          alerts = jsonDecode(alertsResponse.body);
        });
      }
    } catch (e) {
      setState(() => status = "Error: $e");
    }
  }

  List<FlSpot> buildMoistureSpots() {
    final reversed = history.reversed.toList();
    return List.generate(reversed.length, (i) {
      final moisture = (reversed[i]['moisture'] as num).toDouble();
      return FlSpot(i.toDouble(), moisture);
    });
  }

  void showAlertsSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => ListView(
        padding: const EdgeInsets.all(16),
        children: alerts.isEmpty
            ? [const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No alerts yet'),
              )]
            : alerts.map<Widget>((alert) {
                Color color;
                switch (alert['severity']) {
                  case 'critical':
                    color = Colors.red;
                    break;
                  case 'warning':
                    color = Colors.orange;
                    break;
                  default:
                    color = Colors.blue;
                }
                return Card(
                  child: ListTile(
                    leading: Icon(Icons.warning, color: color),
                    title: Text(alert['message']),
                    subtitle: Text(alert['type']),
                  ),
                );
              }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = alerts.where((a) => a['acknowledged'] == false).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(farmerName != null ? 'AgriMitra — $farmerName' : 'AgriMitra Dashboard'),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications),
                onPressed: showAlertsSheet,
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '$unreadCount',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: logout,
          ),
        ],
      ),
      body: sensorData == null
          ? Center(child: Text(status))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text('Device: ${sensorData!['deviceId']}',
                      style: const TextStyle(fontSize: 18)),
                  const SizedBox(height: 12),
                  MoistureGauge(moisture: (sensorData!['moisture'] as num).toDouble()),
                  const SizedBox(height: 8),
                  Text('Temperature: ${sensorData!['temperature']}°C',
                      style: const TextStyle(fontSize: 18)),
                  const SizedBox(height: 8),
                  Text('Humidity: ${sensorData!['humidity']}%',
                      style: const TextStyle(fontSize: 18)),

                  const SizedBox(height: 20),
                  if (irrigationData != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: irrigationData!['shouldIrrigate'] == true
                            ? Colors.blue.shade50
                            : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: irrigationData!['shouldIrrigate'] == true
                              ? Colors.blue
                              : Colors.orange,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                irrigationData!['shouldIrrigate'] == true
                                    ? Icons.water_drop
                                    : Icons.water_drop_outlined,
                                color: irrigationData!['shouldIrrigate'] == true
                                    ? Colors.blue
                                    : Colors.orange,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                irrigationData!['shouldIrrigate'] == true
                                    ? 'Irrigation recommended'
                                    : 'No irrigation needed',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(irrigationData!['reason'] ?? ''),
                          const SizedBox(height: 8),
                          Text(
                            'ET0: ${irrigationData!['ET0']} mm | Crop demand: ${irrigationData!['cropWaterDemandMm']} mm | Rain chance: ${irrigationData!['rainProbability']}%',
                            style: const TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 20),
                  if (cropData != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.eco, color: Colors.green),
                              const SizedBox(width: 8),
                              Text(
                                'Recommended crop: ${cropData!['recommended_crop']}',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text('Other good options:', style: TextStyle(fontSize: 12, color: Colors.black54)),
                          ...List.generate(
                            (cropData!['top_3'] as List).length,
                            (i) {
                              final item = cropData!['top_3'][i];
                              return Text(
                                '${item['crop']} (${(item['confidence'] * 100).toStringAsFixed(0)}% confidence)',
                                style: const TextStyle(fontSize: 12, color: Colors.black54),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Moisture history',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 220,
                    child: history.isEmpty
                        ? const Center(child: Text('No history yet'))
                        : LineChart(
                            LineChartData(
                              minY: 0,
                              maxY: 100,
                              gridData: const FlGridData(show: true),
                              titlesData: const FlTitlesData(
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                rightTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                topTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                              ),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: buildMoistureSpots(),
                                  isCurved: true,
                                  color: Colors.green,
                                  barWidth: 3,
                                  dotData: const FlDotData(show: false),
                                ),
                              ],
                            ),
                          ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: fetchData,
                    child: const Text('Refresh now'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ChatScreen()),
                      );
                    },
                    icon: const Icon(Icons.chat),
                    label: const Text('Ask AgriMitra'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const CalendarScreen()),
                      );
                    },
                    icon: const Icon(Icons.calendar_month),
                    label: const Text('Farm Calendar'),
                  ),
                ],
              ),
            ),
    );
  }
}