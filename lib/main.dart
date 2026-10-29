import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Malama Aira Offline Tutor',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      home: const ModelInitializerScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// 1. Model Downloader & Verification Screen
class ModelInitializerScreen extends StatefulWidget {
  const ModelInitializerScreen({super.key});

  @override
  State<ModelInitializerScreen> createState() => _ModelInitializerScreenState();
}

class _ModelInitializerScreenState extends State<ModelInitializerScreen> {
  bool isDownloading = false;
  double downloadProgress = 0.0;
  String statusMessage = "Checking local AI storage...";

  // Direct download link for your Hugging Face 1.5B model file
  final String modelUrl =
      "https://huggingface.co/IhArmayau/malama-aira-direct-1.5b-gguf/resolve/main/Qwen2.5-1.5B-Instruct.Q4_K_M.gguf";
  final String fileName = "Qwen2.5-1.5B-Instruct.Q4_K_M.gguf";

  @override
  void initState() {
    super.initState();
    _checkAndPrepareModel();
  }

  Future<void> _checkAndPrepareModel() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final filePath = "${dir.path}/$fileName";
      final file = File(filePath);

      if (await file.exists()) {
        setState(() {
          statusMessage = "AI Model found locally! Launching...";
        });
        await Future.delayed(const Duration(milliseconds: 600));
        _navigateToChat(filePath);
      } else {
        await _downloadModel(filePath);
      }
    } catch (e) {
      setState(() {
        statusMessage = "Error preparing model: $e";
      });
    }
  }

  Future<void> _downloadModel(String savePath) async {
    setState(() {
      isDownloading = true;
      statusMessage = "Downloading Malama Aira 1.5B Model (~986 MB)...";
    });

    try {
      Dio dio = Dio();
      await dio.download(
        modelUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            setState(() {
              downloadProgress = received / total;
            });
          }
        },
      );

      setState(() {
        isDownloading = false;
        statusMessage = "Download complete! Initializing tutor...";
      });

      await Future.delayed(const Duration(milliseconds: 800));
      _navigateToChat(savePath);
    } catch (e) {
      setState(() {
        isDownloading = false;
        statusMessage = "Download failed. Check internet connection: $e";
      });
    }
  }

  void _navigateToChat(String modelPath) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(modelPath: modelPath),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.teal),
              const SizedBox(height: 24),
              Text(
                statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              if (isDownloading) ...[
                const SizedBox(height: 20),
                LinearProgressIndicator(
                  value: downloadProgress,
                  color: Colors.teal,
                  backgroundColor: Colors.teal[50],
                ),
                const SizedBox(height: 12),
                Text(
                  "${(downloadProgress * 100).toStringAsFixed(1)}%",
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 2. Main Chat Screen
class ChatScreen extends StatefulWidget {
  final String modelPath;
  const ChatScreen({super.key, required this.modelPath});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // widget.modelPath contains the absolute path to your downloaded .gguf file
    // Pass this path directly to llama_cpp_dart when you set up your inference engine
  }

  void _sendMessage() async {
    String text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({"sender": "user", "text": text});
      _isLoading = true;
    });
    _controller.clear();

    // Placeholder response simulation
    await Future.delayed(const Duration(milliseconds: 800));

    setState(() {
      _messages.add({
        "sender": "aira",
        "text": "Model path loaded: ${widget.modelPath.split('/').last}. Ready for offline LLM queries!"
      });
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Malama Aira (100% Offline)"),
        backgroundColor: Colors.teal,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                bool isUser = msg["sender"] == "user";
                return Container(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Container(
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.teal[100] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    child: Text(
                      msg["text"] ?? "",
                      style: const TextStyle(fontSize: 16.0),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: "Ask physics, math, or biology...",
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _isLoading ? null : _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8.0),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.teal),
                  onPressed: _isLoading ? null : _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}