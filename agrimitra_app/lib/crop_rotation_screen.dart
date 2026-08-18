import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';
import 'theme.dart';
import 'localization.dart';

class CropRotationScreen extends StatefulWidget {
  const CropRotationScreen({super.key});

  @override
  State<CropRotationScreen> createState() => _CropRotationScreenState();
}

class _CropRotationScreenState extends State<CropRotationScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedSoilType;
  String? _selectedPreviousCrop;

  double? _temperature;
  double? _humidity;
  double? _rainfall;
  bool _isUsingFallbackRainfall = false;
  bool _isLoadingWeather = false;
  bool _isLoadingRainfall = false;
  bool _isSubmitting = false;
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
    'Rice', 'Wheat', 'Maize', 'Sorghum', 'Pearl Millet', 'Finger Millet',
    'Chickpea', 'Lentil', 'Pigeon Pea', 'Black Gram', 'Green Gram',
    'Soybean', 'Groundnut', 'Mustard', 'Sunflower', 'Sesame',
    'Cotton', 'Sugarcane', 'Tomato', 'Brinjal', 'Chili', 'Potato',
  ];

  // Regional seasonal rainfall fallback (mm) by soil type — environmental, not crop-specific
  static const Map<String, double> _fallbackRainfall = {
    'Black Soil': 600,
    'Red Soil': 500,
    'Alluvial Soil': 1000,
    'Sandy Soil': 300,
    'Clay Soil': 1000,
    'Laterite Soil': 1250,
  };

  @override
  void initState() {
    super.initState();
    _fetchWeatherData();
  }

  Future<Map<String, String>> _getAuthHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    return {'Authorization': 'Bearer $token'};
  }

  Future<void> _fetchWeatherData() async {
    setState(() => _isLoadingWeather = true);
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('${Config.apiBaseUrl}/api/sensors/esp32-01/latest'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _temperature = (data['temperature'] as num?)?.toDouble();
            _humidity = (data['humidity'] as num?)?.toDouble();
            _isLoadingWeather = false;
          });
        }
      } else {
        debugPrint('[Weather] HTTP ${response.statusCode}: ${response.body}');
        if (mounted) setState(() => _isLoadingWeather = false);
      }
    } catch (e) {
      debugPrint('[Weather] Fetch failed: $e');
      if (mounted) setState(() => _isLoadingWeather = false);
    }
  }

  Future<void> _fetchRainfallEstimate(String soilType) async {
    setState(() {
      _isLoadingRainfall = true;
      _rainfall = null;
      _isUsingFallbackRainfall = false;
    });
    try {
      final response = await http.get(
        Uri.parse('http://localhost:5001/rainfall-estimate?soil_type=$soilType'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final value = (data['rainfall_mm'] as num?)?.toDouble();
        if (mounted) {
          setState(() {
            _rainfall = value;
            _isUsingFallbackRainfall = false;
            _isLoadingRainfall = false;
          });
        }
      } else {
        debugPrint('[Rainfall] HTTP ${response.statusCode}: ${response.body}');
        _applyFallbackRainfall(soilType);
      }
    } catch (e) {
      debugPrint('[Rainfall] Fetch failed: $e');
      _applyFallbackRainfall(soilType);
    }
  }

  void _applyFallbackRainfall(String soilType) {
    final fallback = _fallbackRainfall[soilType];
    if (fallback != null && mounted) {
      setState(() {
        _rainfall = fallback;
        _isUsingFallbackRainfall = true;
        _isLoadingRainfall = false;
      });
    } else if (mounted) {
      setState(() {
        _rainfall = 700;
        _isUsingFallbackRainfall = true;
        _isLoadingRainfall = false;
      });
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _getRecommendation() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedSoilType == null || _selectedPreviousCrop == null) {
      _showSnackBar('Please select both soil type and previous crop');
      return;
    }
    if (_temperature == null || _humidity == null) {
      _showSnackBar('Weather data not available. Please try again.');
      return;
    }

    // Use fallback rainfall if API failed — don't block the feature
    final rainfallToUse = _rainfall ?? _fallbackRainfall[_selectedSoilType!] ?? 700;

    setState(() => _isSubmitting = true);

    try {
      final response = await http.post(
        Uri.parse('http://localhost:5001/recommend-crop'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'soil_type': _selectedSoilType,
          'previous_crop': _selectedPreviousCrop,
          'temperature': _temperature,
          'humidity': _humidity,
          'rainfall': rainfallToUse,
        }),
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _recommendations = data['recommendations'] as List<dynamic>?;
          _isSubmitting = false;
        });
      } else {
        String msg;
        try {
          final body = jsonDecode(response.body);
          msg = body['error']?.toString() ?? 'Server error (${response.statusCode})';
        } catch (_) {
          msg = 'Server error (${response.statusCode})';
        }
        setState(() => _isSubmitting = false);
        _showSnackBar(msg);
      }
    } catch (e) {
      debugPrint('[Recommend] Request failed: $e');
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showSnackBar('Crop model service unavailable — make sure the model server is running');
    }
  }

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalization.instance;

    return Scaffold(
      appBar: AppBar(
        title: Text(localization.t('crop_rotation')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localization.t('crop_rotation_subtitle'),
                  style: const TextStyle(fontSize: 14, color: AgriMitraColors.inkMuted),
                ),
                const SizedBox(height: 24),
                DropdownButtonFormField<String>(
                  initialValue: _selectedSoilType,
                  decoration: const InputDecoration(
                    labelText: 'Soil Type',
                    prefixIcon: Icon(Icons.landscape, size: 20),
                  ),
                  items: _soilTypes
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) {
                    setState(() => _selectedSoilType = v);
                    if (v != null) _fetchRainfallEstimate(v);
                  },
                  validator: (v) => v == null ? 'Please select a soil type' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedPreviousCrop,
                  decoration: const InputDecoration(
                    labelText: 'Previous Crop',
                    prefixIcon: Icon(Icons.eco_outlined, size: 20),
                  ),
                  items: _crops
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedPreviousCrop = v),
                  validator: (v) => v == null ? 'Please select a previous crop' : null,
                ),
                const SizedBox(height: 20),
                _buildConditionsSummary(),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _getRecommendation,
                    icon: _isSubmitting
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
                      _isSubmitting ? '...' : localization.t('get_recommendation'),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                if (_recommendations != null) ...[
                  const Text(
                    'Recommendations',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AgriMitraColors.ink,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._recommendations!.map((rec) => _buildResultCard(rec)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConditionsSummary() {
    final parts = <String>[];

    if (_isLoadingWeather) {
      parts.add('Fetching weather...');
    } else if (_temperature != null && _humidity != null) {
      parts.add('${_temperature!.toStringAsFixed(1)}°C, ${_humidity!.toStringAsFixed(0)}% humidity');
    } else {
      parts.add('Weather data unavailable');
    }

    if (_isLoadingRainfall) {
      parts.add('Estimating rainfall...');
    } else if (_rainfall != null && _selectedPreviousCrop != null) {
      final label = _isUsingFallbackRainfall ? 'Seasonal avg' : 'Estimated';
      parts.add('~${_rainfall!.toStringAsFixed(0)}mm rainfall ($label)');
    } else if (_selectedPreviousCrop != null) {
      parts.add('Rainfall estimate unavailable');
    }

    if (parts.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AgriMitraColors.softGreen,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AgriMitraColors.lightGreenBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: AgriMitraColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              parts.join(' · '),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AgriMitraColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(dynamic rec) {
    final rank = rec['rank'] as int;
    final crop = rec['crop'] as String;
    final overallFit = (rec['overall_fit_score'] as num).toInt();
    final reason = rec['rotation_fit_reason'] as String;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AgriMitraColors.lightGreenBorder),
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
              color: AgriMitraColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '#$rank',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: AgriMitraColors.primary,
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
                        'Overall Fit: $overallFit%',
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
          const Icon(Icons.check_circle, color: AgriMitraColors.primary, size: 18),
        ],
      ),
    );
  }
}
