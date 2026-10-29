import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

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
      // 1. Check public Download folder first
      final downloadDir = Directory('/storage/emulated/0/Download');
      final publicFile = File('${downloadDir.path}/$fileName');

      if (await publicFile.exists()) {
        setState(() {
          statusMessage = "Model found in Download folder! Launching...";
        });
        await Future.delayed(const Duration(milliseconds: 600));
        _navigateToChat(publicFile.path);
        return;
      }

      // 2. Check private app internal storage
      final dir = await getApplicationDocumentsDirectory();
      final privateFilePath = "${dir.path}/$fileName";
      final privateFile = File(privateFilePath);

      if (await privateFile.exists()) {
        setState(() {
          statusMessage = "AI Model found locally! Launching...";
        });
        await Future.delayed(const Duration(milliseconds: 600));
        _navigateToChat(privateFilePath);
      } else {
        // 3. Otherwise, auto-download via Dio
        await _downloadModel(privateFilePath);
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

/// 2. Main Chat Screen with Real Llama.cpp Inference
class ChatScreen extends StatefulWidget {
  final String modelPath;
  const ChatScreen({super.key, required this.modelPath});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List> _messages = [];
  bool _isLoading = false;
  Llama? _llama;
  bool _isModelLoaded = false;

  @override
  void initState() {
    super.initState();
    _initLlamaModel();
  }

  Future<void> _initLlamaModel() async {
    try {
      setState(() {
        _messages.add({
          "sender": "aira",
          "text": "Loading model into memory... Please wait a moment."
        });
      });

      // Initialize llama_cpp_dart with the GGUF file path
      _llama = Llama(widget.modelPath);
      
      setState(() {
        _isModelLoaded = true;
        _messages.last["text"] = "Malama Aira is fully loaded and ready offline! Ask me anything.";
      });
    } catch (e) {
      setState(() {
        _messages.last["text"] = "Failed to load GGUF model: $e";
      });
    }
  }

  void _sendMessage() async {
    String text = _controller.text.trim();
    if (text.isEmpty || !_isModelLoaded || _llama == null) return;

    setState(() {
      _messages.add({"sender": "user", "text": text});
      _messages.add({"sender": "aira", "text": ""}); // Placeholder for token streaming
      _isLoading = true;
    });
    _controller.clear();

    try {
      _llama!.setPrompt(text);
      String fullResponse = "";

      while (true) {
        var (token, done) = _llama!.getNext();
        if (token.isNotEmpty) {
          fullResponse += token;
          setState(() {
            _messages.last["text"] = fullResponse;
          });
        }
        if (done) break;
      }
    } catch (e) {
      setState(() {
        _messages.last["text"] = "Inference error: $e";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _llama?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Malama Aira (100% Offline AI)"),
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
                    decoration: InputDecoration(
                      hintText: _isModelLoaded ? "Ask physics, math, or biology..." : "Loading model...",
                      border: const OutlineInputBorder(),
                    ),
                    enabled: _isModelLoaded && !_isLoading,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8.0),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.teal),
                  onPressed: (_isModelLoaded && !_isLoading) ? _sendMessage : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}