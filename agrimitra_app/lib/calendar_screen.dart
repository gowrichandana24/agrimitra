import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'crop_setup_screen.dart';
import 'config.dart';
import 'theme.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  List<dynamic> allEvents = [];
  Map<String, dynamic>? profile;
  bool isLoading = true;

  DateTime focusedDay = DateTime.now();
  DateTime? selectedDay;

  final String allEventsUrl = "${Config.apiBaseUrl}/api/calendar/esp32-01/all";
  final String createUrl = "${Config.apiBaseUrl}/api/calendar";

  final titleController = TextEditingController();
  final notesController = TextEditingController();
  String selectedType = 'custom';
  DateTime newEventDate = DateTime.now().add(const Duration(days: 1));

  final Map<String, String> typeLabels = {
    'sowing': 'Sowing',
    'fertilizing': 'Fertilizing',
    'irrigation_check': 'Irrigation check',
    'harvest': 'Harvest',
    'custom': 'Custom reminder',
  };

  @override
  void initState() {
    super.initState();
    selectedDay = DateTime.now();
    fetchProfile();
    fetchEvents();
  }

  Future<Map<String, String>> getAuthHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    return {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'};
  }

  Future<void> fetchProfile() async {
    try {
      final headers = await getAuthHeaders();
      final response = await http.get(
        Uri.parse('${Config.apiBaseUrl}/api/auth/profile'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        setState(() {
          profile = jsonDecode(response.body);
        });
      }
    } catch (e) {
      // fail silently
    }
  }

  Future<void> fetchEvents() async {
    setState(() => isLoading = true);
    try {
      final headers = await getAuthHeaders();
      final response = await http.get(Uri.parse(allEventsUrl), headers: headers);
      if (response.statusCode == 200) {
        setState(() {
          allEvents = jsonDecode(response.body);
        });
      }
    } catch (e) {
      // silently fail for now
    } finally {
      setState(() => isLoading = false);
    }
  }

  // Normalizes a date to just year/month/day, so time-of-day differences
  // don't break matching events to calendar cells.
  DateTime normalize(DateTime d) => DateTime(d.year, d.month, d.day);

  List<dynamic> eventsForDay(DateTime day) {
    final target = normalize(day);
    return allEvents.where((e) {
      final eventDate = normalize(DateTime.parse(e['eventDate']).toLocal());
      return eventDate == target;
    }).toList();
  }

  Future<void> addEvent() async {
    if (titleController.text.trim().isEmpty) return;

    try {
      final headers = await getAuthHeaders();
      final response = await http.post(
        Uri.parse(createUrl),
        headers: headers,
        body: jsonEncode({
          'deviceId': 'esp32-01',
          'title': titleController.text.trim(),
          'type': selectedType,
          'eventDate': newEventDate.toIso8601String(),
          'notes': notesController.text.trim(),
        }),
      );

      if (response.statusCode == 201) {
        titleController.clear();
        notesController.clear();
        if (mounted) Navigator.pop(context);
        fetchEvents();
      }
    } catch (e) {
      // could show a snackbar here later
    }
  }

  Future<void> markComplete(String eventId) async {
    try {
      final headers = await getAuthHeaders();
      await http.patch(
        Uri.parse('${Config.apiBaseUrl}/api/calendar/$eventId/complete'),
        headers: headers,
      );
      fetchEvents();
    } catch (e) {
      // could show a snackbar here later
    }
  }

  void showAddEventSheet() {
    newEventDate = selectedDay ?? DateTime.now();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: StatefulBuilder(
          builder: (context, setSheetState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add reminder', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                items: typeLabels.entries
                    .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (value) => setSheetState(() => selectedType = value!),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Date: ${newEventDate.toLocal().toString().split(' ')[0]}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: newEventDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 30)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setSheetState(() => newEventDate = picked);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'Notes (optional)', border: OutlineInputBorder()),
                maxLines: 2,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: addEvent,
                child: const Text('Save reminder'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData iconForType(String type) {
    switch (type) {
      case 'sowing': return Icons.grass;
      case 'fertilizing': return Icons.science;
      case 'irrigation_check': return Icons.water_drop;
      case 'harvest': return Icons.agriculture;
      default: return Icons.event_note;
    }
  }

  Color colorForType(String type) {
    switch (type) {
      case 'sowing': return AgriMitraColors.ink;
      case 'fertilizing': return AgriMitraColors.water;
      case 'irrigation_check': return AgriMitraColors.water;
      case 'harvest': return AgriMitraColors.accent;
      default: return AgriMitraColors.primary;
    }
  }

  Widget buildGrowthStatusBanner() {
    if (profile == null || profile!['currentCrop'] == null) {
      return Card(
        margin: const EdgeInsets.all(12),
        child: ListTile(
          leading: const Icon(Icons.add_circle_outline, color: AgriMitraColors.primary),
          title: const Text('No crop set yet'),
          subtitle: const Text('Tap to tell us what you\'re growing'),
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CropSetupScreen()),
            );
            if (result == true) {
              fetchProfile();
              fetchEvents();
            }
          },
        ),
      );
    }

    final status = profile!['growthStatus'];
    return Card(
      margin: const EdgeInsets.all(12),
      color: AgriMitraColors.primaryLight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.eco, color: AgriMitraColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${profile!['currentCrop']} — ${status?['stage'] ?? ''} stage, ${status?['daysToHarvest'] ?? '?'} days to harvest',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CropSetupScreen()),
                );
                if (result == true) {
                  fetchProfile();
                  fetchEvents();
                }
              },
              child: const Text('Change'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dayEvents = eventsForDay(selectedDay ?? DateTime.now());

    return Scaffold(
      appBar: AppBar(title: const Text('Farm Calendar')),
      floatingActionButton: FloatingActionButton(
        onPressed: showAddEventSheet,
        child: const Icon(Icons.add),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                  buildGrowthStatusBanner(),
                  TableCalendar(
                    firstDay: DateTime.now().subtract(const Duration(days: 365)),
                    lastDay: DateTime.now().add(const Duration(days: 365)),
                    focusedDay: focusedDay,
                    selectedDayPredicate: (day) => isSameDay(selectedDay, day),
                    eventLoader: eventsForDay,
                    calendarFormat: CalendarFormat.month,
                    onDaySelected: (selected, focused) {
                      setState(() {
                        selectedDay = selected;
                        focusedDay = focused;
                      });
                    },
                    calendarStyle: const CalendarStyle(
                      todayDecoration: BoxDecoration(color: AgriMitraColors.primary, shape: BoxShape.circle),
                      selectedDecoration: BoxDecoration(color: AgriMitraColors.ink, shape: BoxShape.circle),
                      markerDecoration: BoxDecoration(color: AgriMitraColors.accent, shape: BoxShape.circle),
                      markersMaxCount: 3,
                    ),
                    headerStyle: const HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        selectedDay != null
                            ? "${selectedDay!.day}/${selectedDay!.month}/${selectedDay!.year}"
                            : "Select a day",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  dayEvents.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('No events on this day'),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: dayEvents.length,
                          itemBuilder: (context, index) {
                            final event = dayEvents[index];
                            final isCompleted = event['completed'] == true;
                            return Card(
                              child: ListTile(
                                leading: Icon(iconForType(event['type']), color: colorForType(event['type'])),
                                title: Text(
                                  event['title'],
                                  style: TextStyle(
                                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                                    color: isCompleted ? AgriMitraColors.inkMuted : null,
                                  ),
                                ),
                                subtitle: event['notes'] != null && event['notes'].toString().isNotEmpty
                                    ? Text(event['notes'])
                                    : null,
                                trailing: isCompleted
                                    ? const Icon(Icons.check_circle, color: AgriMitraColors.primary)
                                    : IconButton(
                                        icon: const Icon(Icons.check_circle_outline),
                                        tooltip: 'Mark as done',
                                        onPressed: () => markComplete(event['_id']),
                                      ),
                              ),
                            );
                          },
                        ),
                  const SizedBox(height: 80), // room so FAB doesn't cover last item
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}