import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Map<String, String> supportedLanguages = {
  'en-IN': 'English',
  'hi-IN': 'हिन्दी',
  'ta-IN': 'தமிழ்',
  'ml-IN': 'മലയാളം',
  'kn-IN': 'ಕನ್ನಡ',
};

class ChatMessage {
  final String text;
  final bool isUser;
  ChatMessage({required this.text, required this.isUser});
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController controller = TextEditingController();
  final List<ChatMessage> messages = [];
  bool isLoading = false;
  bool isLoadingHistory = true;

  final stt.SpeechToText speech = stt.SpeechToText();
  final FlutterTts tts = FlutterTts();
  bool isListening = false;
  bool speechAvailable = false;
  bool autoSpeak = true;
  bool isSpeaking = false;

  String selectedLanguage = 'en-IN';
  Set<String> availableSttLocales = {};
  bool sttLocalesLoaded = false;

  final String chatUrl = "http://localhost:5000/api/chat/esp32-01/ask";
  final String historyUrl = "http://localhost:5000/api/chat/history";
  final String profileUrl = "http://localhost:5000/api/auth/profile";

  @override
  void initState() {
    super.initState();
    initSpeech();
    initTts();
    loadPreferences();
    loadChatHistory();
  }

  Future<void> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLang = prefs.getString('preferredLanguage');
    if (savedLang != null && supportedLanguages.containsKey(savedLang)) {
      setState(() => selectedLanguage = savedLang);
    }

    // Also try to load from backend profile
    try {
      final token = prefs.getString('token');
      if (token != null) {
        final response = await http.get(
          Uri.parse(profileUrl),
          headers: {'Authorization': 'Bearer $token'},
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final backendLang = data['preferredLanguage'];
          if (backendLang != null && supportedLanguages.containsKey(backendLang)) {
            setState(() => selectedLanguage = backendLang);
            await prefs.setString('preferredLanguage', backendLang);
          }
        }
      }
    } catch (_) {}
  }

  Future<void> persistLanguage(String langCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('preferredLanguage', langCode);

    // Sync to backend profile
    try {
      final token = prefs.getString('token');
      if (token != null) {
        await http.patch(
          Uri.parse(profileUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'preferredLanguage': langCode}),
        );
      }
    } catch (_) {}
  }

  Future<void> loadChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.get(
        Uri.parse(historyUrl),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          messages.addAll(data.map((m) => ChatMessage(
                text: m['text'],
                isUser: m['role'] == 'user',
              )));
        });
      }
    } catch (e) {
      print('Failed to load chat history: $e');
    } finally {
      setState(() => isLoadingHistory = false);
    }
  }

  Future<void> initSpeech() async {
    speechAvailable = await speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          setState(() => isListening = false);
        }
      },
      onError: (error) => setState(() => isListening = false),
    );
    if (speechAvailable) {
      final locales = await speech.locales();
      setState(() {
        availableSttLocales = locales.map((l) => l.localeId).toSet();
        sttLocalesLoaded = true;
      });
    }
    setState(() {});
  }

  void initTts() {
    tts.setStartHandler(() {
      setState(() => isSpeaking = true);
    });
    tts.setCompletionHandler(() {
      setState(() => isSpeaking = false);
    });
    tts.setCancelHandler(() {
      setState(() => isSpeaking = false);
    });
    tts.setErrorHandler((msg) {
      setState(() => isSpeaking = false);
    });
  }

  bool isSttLocaleSupported(String localeCode) {
    if (!sttLocalesLoaded) return false;
    // Check exact match first
    if (availableSttLocales.contains(localeCode)) return true;
    // Check language-only match (e.g. "hi" matches "hi-IN")
    final langOnly = localeCode.split('-').first;
    return availableSttLocales.any((l) => l.startsWith(langOnly));
  }

  String getSttLocale(String localeCode) {
    if (availableSttLocales.contains(localeCode)) return localeCode;
    final langOnly = localeCode.split('-').first;
    final match = availableSttLocales.firstWhere(
      (l) => l.startsWith(langOnly),
      orElse: () => 'en-IN',
    );
    return match;
  }

  void startListening() async {
    if (!speechAvailable) return;

    if (!isSttLocaleSupported(selectedLanguage)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Voice input for ${supportedLanguages[selectedLanguage]} is not available on this device. You can still type.',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    final locale = getSttLocale(selectedLanguage);
    setState(() => isListening = true);
    await speech.listen(
      onResult: (result) {
        setState(() {
          controller.text = result.recognizedWords;
        });
        if (result.finalResult) {
          sendMessage();
        }
      },
      localeId: locale,
    );
  }

  void stopListening() {
    speech.stop();
    setState(() => isListening = false);
  }

  Future<void> speakText(String text) async {
    try {
      await tts.setLanguage(selectedLanguage);
      await tts.setSpeechRate(0.45);
      await tts.speak(text);
    } catch (_) {
      // TTS locale not supported — try language-only fallback
      try {
        final langOnly = selectedLanguage.split('-').first;
        await tts.setLanguage(langOnly);
        await tts.setSpeechRate(0.45);
        await tts.speak(text);
      } catch (_) {
        // Last resort — try English
        try {
          await tts.setLanguage('en-IN');
          await tts.setSpeechRate(0.45);
          await tts.speak(text);
        } catch (__) {}
      }
    }
  }

  Future<void> stopSpeaking() async {
    await tts.stop();
    setState(() => isSpeaking = false);
  }

  Future<void> sendMessage() async {
    final question = controller.text.trim();
    if (question.isEmpty) return;

    setState(() {
      messages.add(ChatMessage(text: question, isUser: true));
      isLoading = true;
      controller.clear();
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.post(
        Uri.parse(chatUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'question': question,
          'language': selectedLanguage,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          messages.add(ChatMessage(text: data['answer'], isUser: false));
        });
        if (autoSpeak) {
          speakText(data['answer']);
        }
      } else {
        print('Chat request failed: ${response.statusCode} - ${response.body}');
        setState(() {
          messages.add(ChatMessage(text: "Something went wrong. Try again.", isUser: false));
        });
      }
    } catch (e) {
      print('Chat request exception: $e');
      setState(() {
        messages.add(ChatMessage(text: "Error: $e", isUser: false));
      });
    } finally {
      setState(() => isLoading = false);
    }
  }

  void showLanguageSelector() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Select Language / भाषा चुनें',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ...supportedLanguages.entries.map((entry) {
              final isSelected = entry.key == selectedLanguage;
              return ListTile(
                leading: Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: isSelected ? Colors.green : null,
                ),
                title: Text(entry.value),
                subtitle: Text(entry.key),
                onTap: () {
                  setState(() => selectedLanguage = entry.key);
                  persistLanguage(entry.key);
                  Navigator.pop(context);
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentLangName = supportedLanguages[selectedLanguage] ?? 'English';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ask AgriMitra'),
        actions: [
          TextButton.icon(
            onPressed: showLanguageSelector,
            icon: const Icon(Icons.language, color: Colors.white, size: 20),
            label: Text(
              currentLangName,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          IconButton(
            icon: Icon(autoSpeak ? Icons.volume_up : Icons.volume_off),
            tooltip: autoSpeak ? 'Auto-speak: ON' : 'Auto-speak: OFF',
            onPressed: () => setState(() => autoSpeak = !autoSpeak),
          ),
        ],
      ),
      body: Column(
        children: [
          if (isLoadingHistory)
            const LinearProgressIndicator(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                return Align(
                  alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(12),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    decoration: BoxDecoration(
                      color: msg.isUser ? Colors.green.shade100 : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Flexible(child: Text(msg.text)),
                        if (!msg.isUser) ...[
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () {
                              if (isSpeaking) {
                                stopSpeaking();
                              } else {
                                speakText(msg.text);
                              }
                            },
                            child: Icon(
                              isSpeaking ? Icons.stop_circle : Icons.volume_up,
                              size: 18,
                              color: isSpeaking ? Colors.red : Colors.black54,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (isSpeaking)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.graphic_eq, size: 16, color: Colors.green),
                  const SizedBox(width: 6),
                  Text(
                    'Speaking in $currentLangName...',
                    style: const TextStyle(fontSize: 12, color: Colors.green),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: stopSpeaking,
                    icon: const Icon(Icons.stop, size: 16),
                    label: const Text('Stop'),
                  ),
                ],
              ),
            ),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          if (!speechAvailable)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'Voice input not available on this device — type instead.',
                style: TextStyle(fontSize: 12, color: Colors.red),
              ),
            ),
          if (speechAvailable && sttLocalesLoaded && !isSttLocaleSupported(selectedLanguage))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'Voice for ${supportedLanguages[selectedLanguage]} not available on this device — type instead.',
                style: const TextStyle(fontSize: 12, color: Colors.orange),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: _getHintText(selectedLanguage),
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                if (speechAvailable)
                  IconButton(
                    icon: Icon(isListening ? Icons.mic : Icons.mic_none),
                    color: isListening ? Colors.red : null,
                    onPressed: isListening ? stopListening : startListening,
                  ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getHintText(String locale) {
    switch (locale) {
      case 'hi-IN':
        return 'अपने खेत के बारे में पूछें...';
      case 'ta-IN':
        return 'உங்கள் பண்ணை பற்றி கேளுங்கள்...';
      case 'ml-IN':
        return 'നിങ്ങളുടെ കൃഷിയെ കുറിച്ച് ചോദിക്കൂ...';
      case 'kn-IN':
        return 'ನಿಮ್ಮ ಕೃಷಿಯ ಬಗ್ಗೆ ಕೇಳಿ...';
      default:
        return 'Ask about your farm...';
    }
  }
}
