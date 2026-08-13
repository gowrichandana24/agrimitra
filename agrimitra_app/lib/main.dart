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
import 'localization.dart';
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
    AppLocalization.instance.loadSavedLanguage();
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
        setState(() => status = "connection_issue");
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
      setState(() => status = "connection_issue");
    }
  }

  List<FlSpot> buildMoistureSpots() {
    final reversed = history.reversed.toList();
    return List.generate(reversed.length, (i) {
      final moisture = (reversed[i]['moisture'] as num).toDouble();
      return FlSpot(i.toDouble(), moisture);
    });
  }

  String _localizedAlertTypeLabel(dynamic rawType) {
    final normalizedType = (rawType ?? 'ALERT').toString().toUpperCase();
    switch (normalizedType) {
      case 'CRITICAL_DRY':
        return AppLocalization.instance.t('alert_type_critical_dry');
      case 'HIGH_TEMP':
        return AppLocalization.instance.t('alert_type_high_temp');
      case 'HEAVY_RAIN_EXPECTED':
        return AppLocalization.instance.t('alert_type_heavy_rain_expected');
      default:
        return AppLocalization.instance.t('alert_type_unknown');
    }
  }

  void showAlertsSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => ListView(
        padding: const EdgeInsets.all(16),
        children: alerts.isEmpty
            ? [Padding(
                padding: const EdgeInsets.all(16),
                child: Text(AppLocalization.instance.t('no_alerts_yet')),
              )]
            : alerts.map<Widget>((alert) {
                Color color;
                switch (alert['severity']) {
                  case 'critical':
                    color = AgriMitraColors.critical;
                    break;
                  case 'warning':
                    color = AgriMitraColors.warning;
                    break;
                  default:
                    color = AgriMitraColors.water;
                }
                return Card(
                  child: ListTile(
                    leading: Icon(Icons.warning, color: color),
                    title: Text(alert['message']),
                    subtitle: Text(_localizedAlertTypeLabel(alert['type'])),
                  ),
                );
              }).toList(),
      ),
    );
  }

  String _weatherConditionLabel() {
    final rainProbability = irrigationData?['rainProbability'];
    if (rainProbability == null) {
      return AppLocalization.instance.t('weather_condition_clear');
    }
    if (rainProbability >= 60) {
      return AppLocalization.instance.t('weather_condition_rain_likely');
    }
    if (rainProbability >= 35) {
      return AppLocalization.instance.t('weather_condition_partly_cloudy');
    }
    return AppLocalization.instance.t('weather_condition_clear');
  }

  String _soilMoistureStatus(double moisture) {
    if (moisture < 15) {
      return AppLocalization.instance.t('status_critical');
    }
    if (moisture < 40) {
      return AppLocalization.instance.t('status_low');
    }
    return AppLocalization.instance.t('status_good');
  }

  Color _soilMoistureColor(String status) {
    switch (status) {
      case 'Critical':
      case 'முக்கியமானது':
        return AgriMitraColors.critical;
      case 'Low':
      case 'குறைவு':
        return AgriMitraColors.warning;
      default:
        return AgriMitraColors.primary;
    }
  }

  String _formatLastUpdated(dynamic rawTimestamp) {
    if (rawTimestamp == null) {
      return AppLocalization.instance.t('just_now');
    }

    final parsed = DateTime.tryParse(rawTimestamp.toString());
    if (parsed == null) {
      return AppLocalization.instance.t('just_now');
    }

    final now = DateTime.now();
    final diffInMinutes = now.difference(parsed).inMinutes;
    if (diffInMinutes < 60) {
      return '$diffInMinutes ${AppLocalization.instance.t('minute_ago')}';
    }
    final diffInHours = now.difference(parsed).inHours;
    if (diffInHours < 24) {
      return '$diffInHours ${AppLocalization.instance.t('hour_ago')}';
    }
    final diffInDays = now.difference(parsed).inDays;
    return '$diffInDays ${diffInDays == 1 ? AppLocalization.instance.t('day_ago') : AppLocalization.instance.t('days_ago')}';
  }

  Widget _buildStatusCard({
    required String title,
    required IconData icon,
    required String primaryValue,
    required String metaValue,
    required Color accent,
    required Widget? trailing,
  }) {
    final isTamil = AppLocalization.instance.isTamil;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AgriMitraColors.lightGreenBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B3D2E).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: accent, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: isTamil ? 13 : 14,
                      fontWeight: FontWeight.w800,
                      color: AgriMitraColors.ink,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              primaryValue,
              style: TextStyle(
                fontSize: isTamil ? 22 : 24,
                fontWeight: FontWeight.w800,
                color: AgriMitraColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              metaValue,
              maxLines: 3,
              softWrap: true,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: isTamil ? 11 : 12,
                color: AgriMitraColors.inkMuted,
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(height: 10),
              trailing,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAlertListCard(Map<String, dynamic> alert) {
    final severity = (alert['severity'] ?? '').toString().toLowerCase();
    final Color severityColor;
    switch (severity) {
      case 'critical':
        severityColor = AgriMitraColors.critical;
        break;
      case 'warning':
        severityColor = AgriMitraColors.warning;
        break;
      default:
        severityColor = AgriMitraColors.water;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AgriMitraColors.lightGreenBorder, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: severityColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.warning_amber_rounded, color: severityColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _localizedAlertTypeLabel(alert['type']),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AgriMitraColors.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  (alert['message'] ?? '').toString(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AgriMitraColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          if (alert['acknowledged'] == false)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AgriMitraColors.primaryLight,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'New',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AgriMitraColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accent,
    required String badge,
    required List<Widget> body,
  }) {
    final isTamil = AppLocalization.instance.isTamil;
    return Container(
      width: 340,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AgriMitraColors.lightGreenBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: isTamil ? 15 : 16,
                        fontWeight: FontWeight.w800,
                        color: AgriMitraColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isTamil ? 11 : 12,
                        color: AgriMitraColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Text(
                badge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: isTamil ? 10 : 11,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          ...body,
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final isTamil = AppLocalization.instance.isTamil;
    return Expanded(
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          style: TextStyle(
            fontSize: isTamil ? 12 : 14,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalization.instance;
    final unreadCount = alerts.where((a) => a['acknowledged'] == false).length;
    final moistureValue = (sensorData?['moisture'] as num?)?.toDouble() ?? 0;
    final soilStatus = _soilMoistureStatus(moistureValue);
    final cropConfidence = ((cropData?['top_3'] as List?)?.isNotEmpty == true)
        ? ((cropData?['top_3'][0]['confidence'] as num?) ?? 0).toDouble() * 100
        : 0;

    return Scaffold(
      body: sensorData == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off, size: 48, color: AgriMitraColors.inkMuted),
                  const SizedBox(height: 12),
                  Text(
                    localization.t('connection_issue_try_again'),
                    style: const TextStyle(fontSize: 16, color: AgriMitraColors.inkMuted),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: fetchData,
                    icon: const Icon(Icons.refresh),
                    label: Text(localization.t('retry')),
                  ),
                ],
              ),
            )
          : SafeArea(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 280,
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                    color: AgriMitraColors.sidebar,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '🌿 AgriMitra',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 30),
                        _buildSidebarNavItem(
                          icon: Icons.speed,
                          label: localization.t('dashboard'),
                          active: true,
                          onTap: () {},
                        ),
                        _buildSidebarNavItem(
                          icon: Icons.chat_bubble_outline,
                          label: localization.t('ai_assistant'),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const ChatScreen()),
                            );
                          },
                        ),
                        _buildSidebarNavItem(
                          icon: Icons.calendar_month_outlined,
                          label: localization.t('farm_calendar'),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const CalendarScreen()),
                            );
                          },
                        ),
                        _buildSidebarNavItem(
                          icon: Icons.notifications_none,
                          label: localization.t('alerts'),
                          onTap: showAlertsSheet,
                        ),
                        const Spacer(),
                        const Divider(color: Color(0xFF1C5A47)),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            const CircleAvatar(
                              radius: 20,
                              backgroundColor: AgriMitraColors.primaryLight,
                              child: Icon(Icons.person, color: AgriMitraColors.sidebar),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    farmerName ?? localization.t('default_farmer'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    localization.t('location_unavailable'),
                                    style: const TextStyle(
                                      color: AgriMitraColors.sidebarMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          localization.t('welcome_back'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          localization.t('location_placeholder'),
                          style: const TextStyle(
                            color: AgriMitraColors.sidebarMuted,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: logout,
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.logout, size: 18),
                            label: Text(localization.t('logout')),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${localization.t('greeting')}, ${farmerName ?? localization.t('default_farmer')}! 🌿',
                                      style: const TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w800,
                                        color: AgriMitraColors.ink,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      localization.t('dashboard_subtitle'),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: AgriMitraColors.inkMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: localization.currentLanguageCode,
                                      items: const [
                                        DropdownMenuItem(value: 'en', child: Text('English')),
                                        DropdownMenuItem(value: 'ta', child: Text('தமிழ்')),
                                      ],
                                      onChanged: (value) async {
                                        if (value == null) return;
                                        await localization.setLanguage(value);
                                        if (mounted) {
                                          setState(() {});
                                        }
                                      },
                                      isDense: true,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Stack(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.notifications_none, color: AgriMitraColors.sidebar),
                                        onPressed: showAlertsSheet,
                                      ),
                                      if (unreadCount > 0)
                                        Positioned(
                                          right: 7,
                                          top: 7,
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              color: AgriMitraColors.critical,
                                              shape: BoxShape.circle,
                                            ),
                                            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                                            child: Text(
                                              '$unreadCount',
                                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 26),
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: _buildStatusCard(
                                    title: localization.t('weather'),
                                    icon: Icons.wb_cloudy_outlined,
                                    primaryValue: '${sensorData!['temperature']}°C',
                                    metaValue: '${_weatherConditionLabel()} • ${localization.t('humidity')} ${sensorData!['humidity']}%',
                                    accent: AgriMitraColors.water,
                                    trailing: null,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildStatusCard(
                                    title: localization.t('soil_moisture'),
                                    icon: Icons.water_drop_outlined,
                                    primaryValue: '${moistureValue.toStringAsFixed(0)}%',
                                    metaValue: '${localization.t('current_status')}: $soilStatus • ${localization.t('updated')} ${_formatLastUpdated(sensorData!['timestamp'])}',
                                    accent: _soilMoistureColor(soilStatus),
                                    trailing: null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: _buildStatusCard(
                                    title: localization.t('irrigation_status'),
                                    icon: Icons.auto_awesome_outlined,
                                    primaryValue: irrigationData?['shouldIrrigate'] == true ? localization.t('recommended') : localization.t('on_hold'),
                                    metaValue: irrigationData?['reason']?.toString() ?? localization.t('no_irrigation_recommendation_available'),
                                    accent: irrigationData?['shouldIrrigate'] == true ? AgriMitraColors.water : AgriMitraColors.warning,
                                    trailing: null,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildStatusCard(
                                    title: localization.t('crop_match_confidence'),
                                    icon: Icons.eco_outlined,
                                    primaryValue: '${cropConfidence.toStringAsFixed(0)}%',
                                    metaValue: cropData?['top_3']?.isNotEmpty == true
                                        ? '${localization.t('top_match')}: ${cropData!['top_3'][0]['crop']}'
                                        : localization.t('recommendation_data_unavailable'),
                                    accent: AgriMitraColors.primary,
                                    trailing: null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),
                          Row(
                            children: [
                              Text(
                                localization.t('smart_alerts'),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: AgriMitraColors.ink,
                                ),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: showAlertsSheet,
                                child: Text(localization.t('view_all_alerts')),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AgriMitraColors.lightGreenBorder, width: 1),
                            ),
                            child: Column(
                              children: [
                                if (alerts.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Text(localization.t('no_alerts_yet')),
                                  )
                                else
                                  ...List.generate(
                                    alerts.length > 3 ? 3 : alerts.length,
                                    (index) => Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: _buildAlertListCard(alerts[index]),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),
                          Text(
                            localization.t('today_recommendations'),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AgriMitraColors.ink,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              _buildRecommendationCard(
                                title: localization.t('irrigation'),
                                subtitle: localization.t('weather_driven_advice'),
                                icon: Icons.water_drop_outlined,
                                accent: AgriMitraColors.water,
                                badge: irrigationData?['shouldIrrigate'] == true ? localization.t('recommended') : localization.t('low_priority'),
                                body: [
                                  Text(
                                    irrigationData?['reason']?.toString() ?? localization.t('recommendation_data_unavailable_short'),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AgriMitraColors.inkMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'ET0: ${irrigationData?['ET0'] ?? '-'} mm | Demand: ${irrigationData?['cropWaterDemandMm'] ?? '-'} mm | Rain chance: ${irrigationData?['rainProbability'] ?? '-'}%',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AgriMitraColors.inkMuted,
                                    ),
                                  ),
                                ],
                              ),
                              _buildRecommendationCard(
                                title: localization.t('crop_recommendation'),
                                subtitle: localization.t('top_3_prediction_list'),
                                icon: Icons.eco_outlined,
                                accent: AgriMitraColors.primary,
                                badge: cropData?['recommended_crop']?.toString() ?? localization.t('unavailable'),
                                body: [
                                  if (cropData?['top_3'] is List)
                                    ...List.generate(
                                      (cropData!['top_3'] as List).length,
                                      (index) {
                                        final item = cropData!['top_3'][index];
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 6),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                '${index + 1}. ${item['crop']}',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  color: AgriMitraColors.ink,
                                                ),
                                              ),
                                              Text(
                                                '${((item['confidence'] as num?) ?? 0 * 100).toStringAsFixed(0)}%',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AgriMitraColors.primary,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    )
                                  else
                                    Text(
                                      localization.t('recommendation_data_unavailable_short'),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AgriMitraColors.inkMuted,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),
                          Text(
                            localization.t('quick_actions'),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AgriMitraColors.ink,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _buildQuickActionButton(
                                icon: Icons.chat_bubble_outline,
                                label: localization.t('ai_assistant'),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const ChatScreen()),
                                  );
                                },
                              ),
                              const SizedBox(width: 12),
                              _buildQuickActionButton(
                                icon: Icons.calendar_month_outlined,
                                label: localization.t('farm_calendar'),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const CalendarScreen()),
                                  );
                                },
                              ),
                              const SizedBox(width: 12),
                              _buildQuickActionButton(
                                icon: Icons.notifications_none,
                                label: localization.t('alerts'),
                                onTap: showAlertsSheet,
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFEAF6EA), Color(0xFFDDEEDB)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: AgriMitraColors.lightGreenBorder, width: 1),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: const Icon(
                                    Icons.smart_toy_outlined,
                                    size: 36,
                                    color: AgriMitraColors.sidebar,
                                  ),
                                ),
                                const SizedBox(width: 18),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        localization.t('need_help_ask'),
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800,
                                          color: AgriMitraColors.ink,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        localization.t('ai_companion'),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: AgriMitraColors.inkMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (context) => const ChatScreen()),
                                        );
                                      },
                                      icon: const Icon(Icons.chat_bubble_outline),
                                      label: Text(
                                        localization.t('talk_now'),
                                        style: TextStyle(
                                          fontSize: localization.isTamil ? 12 : 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSidebarNavItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
  }) {
    final isTamil = AppLocalization.instance.isTamil;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF14493A) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: active ? Colors.white : AgriMitraColors.sidebarMuted),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: active ? Colors.white : AgriMitraColors.sidebarMuted,
                    fontSize: isTamil ? 13 : 14,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}