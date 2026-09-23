import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import 'theme.dart';
import 'localization.dart';

class PricePredictionScreen extends StatefulWidget {
  const PricePredictionScreen({super.key});

  @override
  State<PricePredictionScreen> createState() => _PricePredictionScreenState();
}

class _PricePredictionScreenState extends State<PricePredictionScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedCrop;
  String? _selectedState;
  String? _selectedDistrict; // '' means "Any district"
  PlatformFile? _pickedImage;

  bool _isSubmitting = false;
  Map<String, dynamic>? _result;

  Map<String, List<String>>? _locations;
  bool _isLoadingLocations = false;
  bool _locationsFailed = false;

  Map<String, dynamic>? _forecast;
  bool _isLoadingHistory = false;

  static const _priceServiceUrl = 'http://localhost:5002';

  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  // Must match the image model's class labels exactly.
  static const _crops = [
    'apple', 'banana', 'beetroot', 'bell pepper', 'cabbage', 'capsicum',
    'carrot', 'cauliflower', 'chilli pepper', 'corn', 'cucumber',
    'eggplant', 'garlic', 'ginger', 'grapes', 'jalepeno', 'kiwi',
    'lemon', 'lettuce', 'mango', 'onion', 'orange', 'paprika', 'pear',
    'peas', 'pineapple', 'pomegranate', 'potato', 'raddish', 'soy beans',
    'spinach', 'sweetcorn', 'sweetpotato', 'tomato', 'turnip', 'watermelon',
  ];

  @override
  void initState() {
    super.initState();
    _fetchLocations();
  }

  @override
  void dispose() {
    super.dispose();
  }

  String _formatChartDate(String isoDate) {
    final parts = isoDate.split('-');
    if (parts.length != 3) return isoDate;
    final day = int.tryParse(parts[2]) ?? 0;
    final month = int.tryParse(parts[1]) ?? 1;
    final monthName =
        (month >= 1 && month <= 12) ? _monthNames[month - 1] : '';
    return '$day $monthName';
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result != null && result.files.single.bytes != null) {
        setState(() => _pickedImage = result.files.single);
      }
    } catch (e) {
      debugPrint('[ImagePick] Failed: $e');
      if (mounted) _showSnackBar('Could not pick image');
    }
  }

  Future<void> _fetchLocations() async {
    setState(() {
      _isLoadingLocations = true;
      _locationsFailed = false;
    });
    try {
      final response = await http
          .get(Uri.parse('$_priceServiceUrl/locations'))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final raw = (data['states'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, (v as List).map((e) => e.toString()).toList()),
      );
      final keys = raw.keys.toList()..sort();
      final sorted = {for (final k in keys) k: raw[k]!};
      if (!mounted) return;
      setState(() {
        _locations = sorted;
        _isLoadingLocations = false;
      });
    } catch (e) {
      debugPrint('[Locations] Fetch failed: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingLocations = false;
        _locationsFailed = true;
      });
    }
  }

  Future<void> _fetchForecast() async {
    if (_selectedCrop == null || _selectedState == null) return;

    setState(() => _isLoadingHistory = true);

    try {
      final params = <String, String>{
        'crop': _selectedCrop!,
        'state': _selectedState!,
      };
      if (_selectedDistrict != null && _selectedDistrict!.isNotEmpty) {
        params['district'] = _selectedDistrict!;
      }
      final uri = Uri.parse('$_priceServiceUrl/price-forecast')
          .replace(queryParameters: params);
      final response =
          await http.get(uri).timeout(const Duration(seconds: 20));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() {
          _forecast = data;
          _isLoadingHistory = false;
        });
      } else {
        setState(() {
          _forecast = null;
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      debugPrint('[PriceForecast] Fetch failed: $e');
      if (!mounted) return;
      setState(() {
        _forecast = null;
        _isLoadingHistory = false;
      });
    }
  }

  Future<void> _getPriceEstimate() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCrop == null) {
      _showSnackBar('Please select a crop');
      return;
    }
    if (_selectedState == null) {
      _showSnackBar('Please select a state');
      return;
    }

    final district = (_selectedDistrict != null && _selectedDistrict!.isNotEmpty)
        ? _selectedDistrict!
        : null;
    final locationText =
        district != null ? '$district, $_selectedState' : _selectedState!;

    setState(() {
      _isSubmitting = true;
      _result = null;
      _forecast = null;
    });

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_priceServiceUrl/predict-price'),
      );

      request.fields['crop'] = _selectedCrop!;
      request.fields['location'] = locationText;
      request.fields['date'] =
          DateTime.now().toIso8601String().substring(0, 10);

      if (_pickedImage?.bytes != null) {
        request.files.add(http.MultipartFile.fromBytes(
          'image',
          _pickedImage!.bytes!,
          filename: _pickedImage!.name,
        ));
      }

      // Diagnostic: confirm exactly what is being sent before the request goes out.
      debugPrint(
        '[Price] Sending predict-price: '
        'pickedImage=${_pickedImage != null} '
        'bytesPresent=${_pickedImage?.bytes != null} '
        'byteLen=${_pickedImage?.bytes?.length} '
        'filesAttached=${request.files.length} '
        'contentType=${request.headers['content-type'] ?? "multipart/form-data (auto)"} '
        'fields=${request.fields.keys}',
      );

      final streamed = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamed);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _result = data as Map<String, dynamic>;
          _isSubmitting = false;
        });
        await _fetchForecast();
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
      debugPrint('[Price] Request failed: $e');
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showSnackBar('Price service unavailable');
    }
  }

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalization.instance;

    return Scaffold(
      appBar: AppBar(
        title: Text(localization.t('price_prediction')),
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
                  localization.t('price_prediction_subtitle'),
                  style: const TextStyle(fontSize: 14, color: AgriMitraColors.inkMuted),
                ),
                const SizedBox(height: 24),
                DropdownButtonFormField<String>(
                  initialValue: _selectedCrop,
                  decoration: const InputDecoration(
                    labelText: 'Crop',
                    prefixIcon: Icon(Icons.eco_outlined, size: 20),
                  ),
                  items: _crops
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedCrop = v),
                  validator: (v) => v == null ? 'Please select a crop' : null,
                ),
                const SizedBox(height: 16),
                _buildLocationSelectors(),
                const SizedBox(height: 20),
                _buildImagePicker(),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _getPriceEstimate,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.currency_rupee),
                    label: Text(
                      _isSubmitting ? '...' : localization.t('get_price_estimate'),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                if (_result != null) ...[
                  const Text(
                    'Price Estimate',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AgriMitraColors.ink,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildResultCard(_result!),
                  const SizedBox(height: 24),
                  _buildForecastSection(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationSelectors() {
    if (_isLoadingLocations) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AgriMitraColors.lightGreenBorder),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Loading states and districts...',
                style: TextStyle(fontSize: 13, color: AgriMitraColors.inkMuted)),
          ],
        ),
      );
    }

    if (_locationsFailed || _locations == null || _locations!.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AgriMitraColors.lightGreenBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.wifi_off, size: 18, color: AgriMitraColors.inkMuted),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Could not load locations',
                  style:
                      TextStyle(fontSize: 13, color: AgriMitraColors.inkMuted)),
            ),
            TextButton.icon(
              onPressed: _fetchLocations,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
              style: TextButton.styleFrom(
                foregroundColor: AgriMitraColors.primary,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
      );
    }

    final districts =
        (_selectedState != null ? _locations![_selectedState] : null) ??
            const <String>[];

    return Column(
      children: [
        DropdownButtonFormField<String>(
          initialValue: _selectedState,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'State',
            prefixIcon: Icon(Icons.location_on_outlined, size: 20),
          ),
          items: _locations!
              .keys
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: (v) {
            setState(() {
              _selectedState = v;
              _selectedDistrict = ''; // reset district when state changes
            });
          },
          validator: (v) => v == null ? 'Please select a state' : null,
        ),
        const SizedBox(height: 16),
        IgnorePointer(
          ignoring: _selectedState == null || districts.isEmpty,
          child: Opacity(
            opacity:
                (_selectedState != null && districts.isNotEmpty) ? 1.0 : 0.5,
            child: DropdownButtonFormField<String>(
              initialValue:
                  (_selectedDistrict == null || _selectedDistrict!.isEmpty)
                      ? ''
                      : _selectedDistrict,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'District (optional)',
                prefixIcon:
                    const Icon(Icons.location_city_outlined, size: 20),
                hintText: _selectedState == null
                    ? 'Select a state first'
                    : 'Any district',
              ),
              items: [
                const DropdownMenuItem(value: '', child: Text('Any district')),
                ...districts.map(
                  (d) => DropdownMenuItem(value: d, child: Text(d)),
                ),
              ],
              onChanged: (v) => setState(() => _selectedDistrict = v ?? ''),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildForecastSection() {
    if (_isLoadingHistory) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AgriMitraColors.lightGreenBorder),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Loading price forecast...',
                style: TextStyle(fontSize: 13, color: AgriMitraColors.inkMuted)),
          ],
        ),
      );
    }

    final forecastData = _forecast;
    final available = forecastData?['data_available'] == true;
    final histPoints = (forecastData?['historical'] as List?) ?? const [];
    final fcPoints = (forecastData?['forecast'] as List?) ?? const [];

    if (!available || histPoints.isEmpty || fcPoints.isEmpty) {
      return _buildForecastUnavailableMessage();
    }

    final spots = <FlSpot>[];
    final xLabels = <String>[];
    for (final p in histPoints) {
      final item = p as Map<String, dynamic>;
      final modal = (item['modal_price'] as num?)?.toDouble();
      if (modal == null) continue;
      spots.add(FlSpot(spots.length.toDouble(), modal));
      xLabels.add(item['date']?.toString() ?? '');
    }
    if (spots.isEmpty) {
      return _buildForecastUnavailableMessage();
    }

    // Forecast line continues directly from the last historical point
    final connectX = (spots.length - 1).toDouble();
    final forecastSpots = <FlSpot>[FlSpot(connectX, spots.last.y)];
    var fx = connectX;
    for (final p in fcPoints) {
      final item = p as Map<String, dynamic>;
      final v = (item['predicted_price'] as num?)?.toDouble();
      fx += 1;
      if (v != null) forecastSpots.add(FlSpot(fx, v));
      xLabels.add(item['date']?.toString() ?? '');
    }

    final allValues = [
      ...spots.map((s) => s.y),
      ...forecastSpots.map((s) => s.y),
    ];
    double minY = allValues.reduce((a, b) => a < b ? a : b);
    double maxY = allValues.reduce((a, b) => a > b ? a : b);
    final yPad = ((maxY - minY).abs() * 0.15) + 1;
    minY = (minY - yPad).clamp(0.0, double.infinity);
    maxY += yPad;

    final confRaw = (forecastData!['trend_confidence'] as num?)?.toDouble();
    final vol = (forecastData['volatility_stddev'] as num?)?.toDouble();
    final note = forecastData['note']?.toString() ?? '';

    final totalSlots = xLabels.length;
    final labelEvery = (totalSlots / 6).ceil().clamp(1, 10000);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '6-Day Price Forecast',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AgriMitraColors.ink,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AgriMitraColors.softGreen,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AgriMitraColors.lightGreenBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline,
                  size: 16, color: AgriMitraColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  note,
                  style:
                      const TextStyle(fontSize: 12, color: AgriMitraColors.ink),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AgriMitraColors.primaryLight,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Confidence: ${confRaw != null ? (confRaw * 100).toStringAsFixed(0) : '-'}%',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AgriMitraColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                vol != null
                    ? 'Typical price varies by ±₹${vol.toStringAsFixed(0)}'
                    : '',
                style:
                    const TextStyle(fontSize: 11, color: AgriMitraColors.inkMuted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(8, 18, 18, 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AgriMitraColors.lightGreenBorder),
          ),
          height: 220,
          child: LineChart(
            LineChartData(
              minY: minY,
              maxY: maxY,
              minX: -0.4,
              maxX: (totalSlots - 1).toDouble() + 0.4,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (v) => const FlLine(
                  color: AgriMitraColors.lightGreenBorder,
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 46,
                    getTitlesWidget: (value, meta) => Text(
                      value.round().toString(),
                      style: const TextStyle(
                          fontSize: 10, color: AgriMitraColors.inkMuted),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 26,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final idx = value.round();
                      if (idx < 0 ||
                          idx >= totalSlots ||
                          (idx % labelEvery != 0 && idx != totalSlots - 1)) {
                        return const SizedBox.shrink();
                      }
                      return Text(
                        _formatChartDate(xLabels[idx]),
                        style: const TextStyle(
                            fontSize: 10, color: AgriMitraColors.inkMuted),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(
                show: true,
                border: const Border(
                  bottom: BorderSide(color: AgriMitraColors.lightGreenBorder),
                  left: BorderSide(color: AgriMitraColors.lightGreenBorder),
                ),
              ),
              lineBarsData: [
                // Historical actual prices — solid green line
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  barWidth: 3,
                  color: AgriMitraColors.primary,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, _, _, _) => FlDotCirclePainter(
                        radius: 3.5, color: AgriMitraColors.primary),
                  ),
                ),
                // Forecast — dashed amber line, connected to last real point
                LineChartBarData(
                  spots: forecastSpots,
                  isCurved: true,
                  barWidth: 2.5,
                  color: AgriMitraColors.warning,
                  dashArray: const [6, 4],
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, _, _, _) => FlDotCirclePainter(
                        radius: 3, color: AgriMitraColors.warning),
                  ),
                ),
              ],
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (touched) => touched.map((t) {
                    final idx = t.x.round();
                    final isPredicted =
                        idx > spots.length - 1 && idx <= connectX.toInt() + fcPoints.length;
                    final dateLabel =
                        idx >= 0 && idx < totalSlots
                            ? _formatChartDate(xLabels[idx])
                            : '';
                    final prefix = isPredicted ? 'Predicted ' : '';
                    return LineTooltipItem(
                      '$prefix$dateLabel\n₹${t.y.round()}',
                      const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _legendDot(AgriMitraColors.primary, 'Actual'),
            const SizedBox(width: 14),
            _legendDot(AgriMitraColors.warning, 'Predicted'),
          ],
        ),
      ],
    );
  }

  Widget _buildForecastUnavailableMessage() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AgriMitraColors.lightGreenBorder),
      ),
      child: const Row(
        children: [
          Icon(Icons.show_chart, size: 18, color: AgriMitraColors.inkMuted),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Not enough historical data to forecast this crop/location',
              style: TextStyle(fontSize: 13, color: AgriMitraColors.inkMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label,
            style:
                const TextStyle(fontSize: 11, color: AgriMitraColors.inkMuted)),
      ],
    );
  }

  Widget _buildImagePicker() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AgriMitraColors.lightGreenBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AgriMitraColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: _pickedImage != null && _pickedImage!.bytes != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      _pickedImage!.bytes!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.image_outlined,
                        color: AgriMitraColors.primary,
                      ),
                    ),
                  )
                : const Icon(
                    Icons.image_outlined,
                    color: AgriMitraColors.primary,
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _pickedImage?.name ?? 'Upload a photo of your produce (optional)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _pickedImage != null
                        ? AgriMitraColors.ink
                        : AgriMitraColors.inkMuted,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.upload_file, size: 16),
                      label: Text(_pickedImage != null ? 'Change' : 'Choose Image'),
                      style: TextButton.styleFrom(
                        foregroundColor: AgriMitraColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    if (_pickedImage != null)
                      TextButton.icon(
                        onPressed: () => setState(() => _pickedImage = null),
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('Remove'),
                        style: TextButton.styleFrom(
                          foregroundColor: AgriMitraColors.critical,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(Map<String, dynamic> result) {
    final estimate = result['price_estimate'] as Map<String, dynamic>;
    final source = estimate['source']?.toString() ?? '';
    final hasData = !source.contains('no data');

    final pricePerQuintal = (estimate['price_per_quintal'] as num?);
    final minPrice = (estimate['min_price'] as num?);
    final maxPrice = (estimate['max_price'] as num?);
    final nRecords = (estimate['n_records_used'] as num?)?.toInt() ?? 0;

    final imageNote = result['note']?.toString();

    return Container(
      width: double.infinity,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AgriMitraColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(
                    Icons.eco_outlined,
                    size: 20,
                    color: AgriMitraColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result['crop_used']?.toString() ?? '-',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AgriMitraColors.ink,
                      ),
                    ),
                    Text(
                      result['location']?.toString() ?? '',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AgriMitraColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: hasData ? AgriMitraColors.primaryLight : AgriMitraColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  hasData ? 'Live Data' : 'No Data',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: hasData ? AgriMitraColors.primary : AgriMitraColors.warning,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 28, color: AgriMitraColors.lightGreenBorder),
          if (!hasData) ...[
            Text(
              estimate['note']?.toString() ?? 'No price data available for this crop.',
              style: const TextStyle(fontSize: 14, color: AgriMitraColors.inkMuted),
            ),
          ] else ...[
            Text(
              '₹$pricePerQuintal',
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: AgriMitraColors.primary,
              ),
            ),
            const Text(
              'per quintal (average modal price)',
              style: TextStyle(fontSize: 12, color: AgriMitraColors.inkMuted),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildPriceRangeTile('Min', minPrice)),
                const SizedBox(width: 12),
                Expanded(child: _buildPriceRangeTile('Max', maxPrice)),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AgriMitraColors.softGreen,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AgriMitraColors.lightGreenBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _prettySource(source),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AgriMitraColors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$nRecords market records · date: ${result['date']}',
                    style: const TextStyle(fontSize: 12, color: AgriMitraColors.inkMuted),
                  ),
                ],
              ),
            ),
          ],
          if (imageNote != null && imageNote.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AgriMitraColors.waterLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.photo_camera_outlined,
                      size: 16, color: AgriMitraColors.water),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      imageNote,
                      style: const TextStyle(
                          fontSize: 12, color: AgriMitraColors.ink),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _prettySource(String rawSource) {
    switch (rawSource) {
      case 'Agmarknet dataset - location-matched':
        return 'Location-matched market data';
      case 'Agmarknet dataset - national average':
        return 'National average — no local match found';
      default:
        return rawSource;
    }
  }

  Widget _buildPriceRangeTile(String label, num? value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AgriMitraColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AgriMitraColors.lightGreenBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AgriMitraColors.inkMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value != null ? '₹$value' : '—',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AgriMitraColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
