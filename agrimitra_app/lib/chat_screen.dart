import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  final stt.SpeechToText speech = stt.SpeechToText();
  final FlutterTts tts = FlutterTts();
  bool isListening = false;
  bool speechAvailable = false;
  bool autoSpeak = false;
  bool isSpeaking = false; // NEW: tracks whether TTS is currently playing

  final String chatUrl = "http://localhost:5000/api/chat/esp32-01/ask";

  @override
  void initState() {
    super.initState();
    initSpeech();
    initTts();
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
    setState(() {});
  }

  void initTts() {
    // NEW: these callbacks keep isSpeaking accurate, including when
    // speech finishes naturally (not just when stopped manually)
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

  void startListening() async {
    if (!speechAvailable) return;
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
      localeId: 'en_IN',
    );
  }

  void stopListening() {
    speech.stop();
    setState(() => isListening = false);
  }

  Future<void> speakText(String text) async {
    await tts.setLanguage('en-IN');
    await tts.setSpeechRate(0.45);
    await tts.speak(text);
  }

  Future<void> stopSpeaking() async {
    await tts.stop();
    setState(() => isSpeaking = false); // in case the platform doesn't fire cancelHandler
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
  body: jsonEncode({'question': question}),
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
        setState(() {
          messages.add(ChatMessage(text: "Something went wrong. Try again.", isUser: false));
        });
      }
    } catch (e) {
      setState(() {
        messages.add(ChatMessage(text: "Error: $e", isUser: false));
      });
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ask AgriMitra'),
        actions: [
          IconButton(
            icon: Icon(autoSpeak ? Icons.volume_up : Icons.volume_off),
            tooltip: autoSpeak ? 'Auto-speak: ON' : 'Auto-speak: OFF',
            onPressed: () => setState(() => autoSpeak = !autoSpeak),
          ),
        ],
      ),
      body: Column(
        children: [
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
                          // NEW: shows a stop icon instead of speaker icon
                          // while this is actively being spoken
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
                  const Text('Speaking...', style: TextStyle(fontSize: 12, color: Colors.green)),
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
                'Voice input not available in this browser — type instead.',
                style: TextStyle(fontSize: 12, color: Colors.red),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      hintText: 'Ask about your farm...',
                      border: OutlineInputBorder(),
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
}