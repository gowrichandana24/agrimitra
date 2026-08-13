import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Map<String, Map<String, String>> _translations = {
  'en': {
    'app_name': 'AgriMitra',
    'dashboard': 'Dashboard',
    'ai_assistant': 'AI Assistant',
    'farm_calendar': 'Farm Calendar',
    'alerts': 'Alerts',
    'settings': 'Settings',
    'logout': 'Logout',
    'welcome_back': 'Welcome Back',
    'greeting': 'Welcome',
    'dashboard_subtitle': "Here's what's happening on your farm today.",
    'status_good': 'Good',
    'status_low': 'Low',
    'status_critical': 'Critical',
    'weather': 'Weather',
    'soil_moisture': 'Soil Moisture',
    'irrigation_status': 'Irrigation Status',
    'crop_match_confidence': 'Crop Match Confidence',
    'smart_alerts': 'Smart Alerts',
    'today_recommendations': "Today's Recommendations",
    'quick_actions': 'Quick Actions',
    'view_all_alerts': 'View All Alerts',
    'need_help_ask': 'Need help? Ask AgriMitra',
    'ai_companion': 'Your AI farming companion',
    'talk_now': 'Talk Now',
    'language_english': 'English',
    'language_tamil': 'தமிழ்',
    'english': 'English',
    'tamil': 'தமிழ்',
    'default_farmer': 'Farmer',
    'connection_issue_try_again': 'Connection issue. Please try again.',
    'no_alerts_yet': 'No alerts yet',
    'location_unavailable': 'Location unavailable',
    'location_placeholder': 'Farmer profile location will appear when available',
    'recommended': 'Recommended',
    'on_hold': 'On hold',
    'top_match': 'Top match',
    'humidity': 'Humidity',
    'weather_condition_clear': 'Clear',
    'weather_condition_partly_cloudy': 'Partly Cloudy',
    'weather_condition_rain_likely': 'Rain Likely',
    'retry': 'Retry',
    'refresh_now': 'Refresh now',
    'current_status': 'Status',
    'updated': 'Updated',
    'just_now': 'Just now',
    'minute_ago': 'min ago',
    'hour_ago': 'hr ago',
    'day_ago': 'day ago',
    'days_ago': 'days ago',
    'top_recommendation': 'Top recommendation',
    'recommendation_data_unavailable': 'Recommendation data unavailable',
    'no_irrigation_recommendation_available': 'No irrigation recommendation available',
    'alert_type_unknown': 'Alert',
    'alert_type_critical_dry': 'Critical - Dry Soil',
    'alert_type_high_temp': 'High Temperature',
    'alert_type_heavy_rain_expected': 'Heavy Rain Expected',
    'irrigation': 'Irrigation',
    'crop_recommendation': 'Crop Recommendation',
    'weather_driven_advice': 'Weather-driven advice',
    'top_3_prediction_list': 'Top-3 prediction list',
    'low_priority': 'Low priority',
    'unavailable': 'Unavailable',
    'recommendation_data_unavailable_short': 'Recommendation data unavailable',
  },
  'ta': {
    'app_name': 'அக்ரிமித்ரா',
    'dashboard': 'டாஷ்போர்டு',
    'ai_assistant': 'AI உதவியாளர்',
    'farm_calendar': 'பண்ணை காலெண்டர்',
    'alerts': 'எச்சரிக்கைகள்',
    'settings': 'அமைப்புகள்',
    'logout': 'வெளியேறு',
    'welcome_back': 'மீண்டும் வரவேற்கிறோம்',
    'greeting': 'வணக்கம்',
    'dashboard_subtitle': 'இன்று உங்கள் பண்ணையில் என்ன நடக்கிறது என்பதை இங்கே பார்க்கலாம்.',
    'status_good': 'நல்லது',
    'status_low': 'குறைவு',
    'status_critical': 'முக்கியமானது',
    'weather': 'வானிலை',
    'soil_moisture': 'மண் ஈரப்பதம்',
    'irrigation_status': 'நீர்ப்பாசன நிலை',
    'crop_match_confidence': 'பயிர் பொருத்த நம்பிக்கை',
    'smart_alerts': 'ஸ்மார்ட் எச்சரிக்கைகள்',
    'today_recommendations': 'இன்றைய பரிந்துரைகள்',
    'quick_actions': 'விரைவான செயல்கள்',
    'view_all_alerts': 'அனைத்து எச்சரிக்கைகளையும் பார்க்க',
    'need_help_ask': 'உதவி வேண்டுமா? அக்ரிமித்ராவிடம் கேளுங்கள்',
    'ai_companion': 'உங்கள் வேளாண் AI உதவியாளர்',
    'talk_now': 'இப்போது பேசுங்கள்',
    'language_english': 'English',
    'language_tamil': 'தமிழ்',
    'english': 'English',
    'tamil': 'தமிழ்',
    'default_farmer': 'விவசாயி',
    'connection_issue_try_again': 'இணைப்பில் சிக்கல். மீண்டும் முயற்சிக்கவும்.',
    'no_alerts_yet': 'இதுவரை எச்சரிக்கை இல்லை',
    'location_unavailable': 'இருப்பிடம் கிடைக்கவில்லை',
    'location_placeholder': 'இருப்பிடம் கிடைத்தால் காட்டப்படும்',
    'recommended': 'பரிந்துரைக்கப்படுகிறது',
    'on_hold': 'இடைநிறுத்தப்பட்டது',
    'top_match': 'சிறந்த பொருத்தம்',
    'humidity': 'ஈரப்பதம்',
    'weather_condition_clear': 'வானம் தெளிவாக உள்ளது',
    'weather_condition_partly_cloudy': 'சில மேகங்கள்',
    'weather_condition_rain_likely': 'மழை ஏற்படலாம்',
    'retry': 'மீண்டும் முயற்சி',
    'refresh_now': 'இப்போது புதுப்பி',
    'current_status': 'நிலை',
    'updated': 'புதுப்பிக்கப்பட்டது',
    'just_now': 'இப்போது',
    'minute_ago': 'நிமிடங்களுக்கு முன்',
    'hour_ago': 'மணி நேரங்களுக்கு முன்',
    'day_ago': 'நாள் முன்',
    'days_ago': 'நாட்களுக்கு முன்',
    'top_recommendation': 'சிறந்த பரிந்துரை',
    'recommendation_data_unavailable': 'பரிந்துரை தரவு கிடைக்கவில்லை',
    'no_irrigation_recommendation_available': 'நீர்ப்பாசன பரிந்துரை இல்லை',
    'alert_type_unknown': 'எச்சரிக்கை',
    'alert_type_critical_dry': 'மிக முக்கியம் - உலர் மண்',
    'alert_type_high_temp': 'அதிக வெப்பநிலை',
    'alert_type_heavy_rain_expected': 'கனமழை வரும் வாய்ப்பு உள்ளது',
    'irrigation': 'நீர்ப்பாசனம்',
    'crop_recommendation': 'பயிர் பரிந்துரை',
    'weather_driven_advice': 'வானிலை சார்ந்த பரிந்துரை',
    'top_3_prediction_list': 'சிறந்த 3 கணிப்பு பட்டியல்',
    'low_priority': 'குறைந்த முன்னுரிமை',
    'unavailable': 'கிடைக்கவில்லை',
    'recommendation_data_unavailable_short': 'பரிந்துரை தரவு கிடைக்கவில்லை',
  },
};

class AppLocalization extends ChangeNotifier {
  AppLocalization._();

  static final AppLocalization instance = AppLocalization._();

  static const String _storageKey = 'app_language_code';
  static const String defaultLanguageCode = 'en';

  String _currentLanguageCode = defaultLanguageCode;

  String get currentLanguageCode => _currentLanguageCode;

  bool get isTamil => _currentLanguageCode == 'ta';

  Future<void> loadSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLanguage = prefs.getString(_storageKey);
    if (savedLanguage != null && _translations.containsKey(savedLanguage)) {
      _currentLanguageCode = savedLanguage;
    } else {
      _currentLanguageCode = defaultLanguageCode;
    }
    notifyListeners();
  }

  Future<void> setLanguage(String languageCode) async {
    if (!_translations.containsKey(languageCode)) {
      return;
    }

    _currentLanguageCode = languageCode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, languageCode);
    notifyListeners();
  }

  String t(String key) {
    final currentMap = _translations[_currentLanguageCode] ?? _translations[defaultLanguageCode]!;
    return currentMap[key] ?? _translations[defaultLanguageCode]![key] ?? key;
  }
}

class AppLocalizationScope extends InheritedWidget {
  const AppLocalizationScope({
    super.key,
    required this.localization,
    required super.child,
  });

  final AppLocalization localization;

  static AppLocalizationScope? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppLocalizationScope>();
  }

  @override
  bool updateShouldNotify(AppLocalizationScope oldWidget) {
    return oldWidget.localization != localization;
  }
}
