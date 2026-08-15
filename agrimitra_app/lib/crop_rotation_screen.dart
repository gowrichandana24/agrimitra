import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'config.dart';
import 'theme.dart';
import 'localization.dart';

class CropRotationScreen extends StatefulWidget {
  const CropRotationScreen({super.key});

  @override
  State<CropRotationScreen> createState() => _CropRotationScreenState();
}

class _CropRotationScreenState extends State<CropRotationScreen> {
  String? _selectedSoilType;
  String? _selectedPreviousCrop;
  final _temperatureController = TextEditingController();
  final _humidityController = TextEditingController();
  final _rainfallController = TextEditingController();

  bool _isLoading = false;
  String? _error;
  List<dynamic>? _recommendations;

  static const _soilTypes = [
    'Black Soil',
    'Red Soil',
    'Alluvial Soil',
    'Sandy Soil',
    'Clay Soil',
    'Laterite Soil',
  ];

  static const _crops = [
    'Rice', 'Wheat', 'Maize', 'Sorghum', 'Chickpea',
    'Lentil', 'Soybean', 'Cotton', 'Sugarcane', 'Tomato', 'Potato',
  ];

  @override
  void dispose() {
    _temperatureController.dispose();
    _humidityController.dispose();
    _rainfallController.dispose();
    super.dispose();
  }

  Future<void> _getRecommendation() async {
    if (_selectedSoilType == null || _selectedPreviousCrop == null) {
      setState(() => _error = 'Please select both soil type and previous crop');
      return;
    }

    final temp = double.tryParse(_temperatureController.text);
    final hum = double.tryParse(_humidityController.text);
    final rain = double.tryParse(_rainfallController.text);

    if (temp == null || hum == null || rain == null) {
      setState(() => _error = 'Please enter valid numeric values for temperature, humidity, and rainfall');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _recommendations = null;
    });

    try {
      final response = await http.post(
        Uri.parse('http://localhost:5001/recommend-crop'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'soil_type': _selectedSoilType,
          'previous_crop': _selectedPreviousCrop,
          'temperature': temp,
          'humidity': hum,
          'rainfall': rain,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _recommendations = data['recommendations'] as List<dynamic>?;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Crop model service returned an error (${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Crop model service unavailable. Make sure the Flask server is running on port 5001.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalization.instance;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: AgriMitraColors.ink),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 4),
                Text(
                  localization.t('crop_rotation'),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AgriMitraColors.ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              localization.t('crop_rotation_subtitle'),
              style: const TextStyle(fontSize: 14, color: AgriMitraColors.inkMuted),
            ),
            const SizedBox(height: 28),
            _buildDropdown(
              label: localization.t('soil_type'),
              value: _selectedSoilType,
              items: _soilTypes,
              onChanged: (v) => setState(() => _selectedSoilType = v),
            ),
            const SizedBox(height: 16),
            _buildDropdown(
              label: localization.t('previous_crop'),
              value: _selectedPreviousCrop,
              items: _crops,
              onChanged: (v) => setState(() => _selectedPreviousCrop = v),
            ),
            const SizedBox(height: 16),
            _buildTextField(
              label: localization.t('temperature_c'),
              controller: _temperatureController,
              icon: Icons.thermostat,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              label: localization.t('humidity_percent'),
              controller: _humidityController,
              icon: Icons.water_drop_outlined,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              label: localization.t('rainfall_mm'),
              controller: _rainfallController,
              icon: Icons.cloud_outlined,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _getRecommendation,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.eco_outlined),
                label: Text(
                  _isLoading ? '...' : localization.t('get_recommendation'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 32),
            if (_error != null) _buildErrorCard(_error!),
            if (_recommendations != null) _buildResultsList(_recommendations!),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AgriMitraColors.lightGreenBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AgriMitraColors.inkMuted,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              hint: Text(
                'Select...',
                style: TextStyle(color: AgriMitraColors.inkMuted),
              ),
              items: items.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AgriMitraColors.lightGreenBorder, width: 1),
      ),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: AgriMitraColors.primary, size: 20),
          labelText: label,
          labelStyle: const TextStyle(color: AgriMitraColors.inkMuted),
          border: InputBorder.none,
          filled: false,
        ),
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF2F2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AgriMitraColors.critical.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AgriMitraColors.critical.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.error_outline, color: AgriMitraColors.critical, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 14, color: AgriMitraColors.critical),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList(List<dynamic> recommendations) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recommendations',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AgriMitraColors.ink,
          ),
        ),
        const SizedBox(height: 12),
        ...recommendations.map((rec) => _buildResultCard(rec)),
      ],
    );
  }

  Widget _buildResultCard(dynamic rec) {
    final rank = rec['rank'] as int;
    final crop = rec['crop'] as String;
    final confidence = (rec['confidence'] as num).toDouble();
    final reason = rec['reason'] as String;
    final isExcluded = reason.toString().toLowerCase().startsWith('excluded');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isExcluded
              ? AgriMitraColors.warning.withValues(alpha: 0.4)
              : AgriMitraColors.lightGreenBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B3D2E).withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isExcluded
                  ? AgriMitraColors.warning.withValues(alpha: 0.12)
                  : AgriMitraColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '#$rank',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: isExcluded ? AgriMitraColors.warning : AgriMitraColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      crop,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AgriMitraColors.ink,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AgriMitraColors.primaryLight,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${(confidence * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AgriMitraColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  reason,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AgriMitraColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          if (isExcluded)
            const Icon(Icons.block, color: AgriMitraColors.warning, size: 18)
          else
            const Icon(Icons.check_circle, color: AgriMitraColors.primary, size: 18),
        ],
      ),
    );
  }
}
