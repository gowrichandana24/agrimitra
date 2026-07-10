import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  List<dynamic> events = [];
  bool isLoading = true;

  final String upcomingUrl = "http://localhost:5000/api/calendar/esp32-01/upcoming";
  final String createUrl = "http://localhost:5000/api/calendar";

  final titleController = TextEditingController();
  final notesController = TextEditingController();
  String selectedType = 'custom';
  DateTime selectedDate = DateTime.now().add(const Duration(days: 1));

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
    fetchEvents();
  }

  Future<Map<String, String>> getAuthHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    return {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'};
  }

  Future<void> fetchEvents() async {
    setState(() => isLoading = true);
    try {
      final headers = await getAuthHeaders();
      final response = await http.get(Uri.parse(upcomingUrl), headers: headers);
      if (response.statusCode == 200) {
        setState(() {
          events = jsonDecode(response.body);
        });
      }
    } catch (e) {
      // silently fail for now, list just stays empty
    } finally {
      setState(() => isLoading = false);
    }
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
          'eventDate': selectedDate.toIso8601String(),
          'notes': notesController.text.trim(),
        }),
      );

      if (response.statusCode == 201) {
        titleController.clear();
        notesController.clear();
        if (mounted) Navigator.pop(context); // close the add-event sheet
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
        Uri.parse('http://localhost:5000/api/calendar/$eventId/complete'),
        headers: headers,
      );
      fetchEvents();
    } catch (e) {
      // could show a snackbar here later
    }
  }

  void showAddEventSheet() {
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
                title: Text('Date: ${selectedDate.toLocal().toString().split(' ')[0]}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setSheetState(() => selectedDate = picked);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Farm Calendar')),
      floatingActionButton: FloatingActionButton(
        onPressed: showAddEventSheet,
        child: const Icon(Icons.add),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : events.isEmpty
              ? const Center(child: Text('No upcoming events — tap + to add one'))
              : RefreshIndicator(
                  onRefresh: fetchEvents,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: events.length,
                    itemBuilder: (context, index) {
                      final event = events[index];
                      final date = DateTime.parse(event['eventDate']).toLocal();
                      final dateStr = "${date.day}/${date.month}/${date.year}";

                      return Card(
                        child: ListTile(
                          leading: Icon(iconForType(event['type']), color: Colors.green),
                          title: Text(event['title']),
                          subtitle: Text(
                            '$dateStr${event['notes'] != null && event['notes'].toString().isNotEmpty ? ' — ${event['notes']}' : ''}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.check_circle_outline),
                            tooltip: 'Mark as done',
                            onPressed: () => markComplete(event['_id']),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}