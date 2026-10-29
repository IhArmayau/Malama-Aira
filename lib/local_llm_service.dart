import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

class LocalLLMService {
  LlamaProcessor? _llamaProcessor;
  bool _isModelLoaded = false;
  
  // Initialize and load the .gguf model from internal storage
  Future<void> initializeModel(String modelFileName) async {
    final Directory appDir = await getApplicationDocumentsDirectory();
    final String modelPath = '${appDir.path}/$modelFileName';

    final file = File(modelPath);
    
    // If the model isn't copied to internal storage yet, copy it from your assets folder
    if (!await file.exists()) {
      final ByteData data = await rootBundle.load('malama-aira-direct-1.5b-gguf/$modelFileName');
      final List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await file.writeAsBytes(bytes, flush: true);
    }

    // Initialize the native llama.cpp processor with the storage path
    _llamaProcessor = LlamaProcessor();
    await _llamaProcessor!.loadModel(modelPath);
    
    _isModelLoaded = true;
  }

  // Stream responses token by token offline from the real model
  Stream<String> generateResponse(String prompt) async* {
    if (!_isModelLoaded || _llamaProcessor == null) {
      yield "Error: Model is not loaded yet.";
      return;
    }

    // Enforce educational prompt structure and Zero-Questions policy
    String formattedPrompt = """[INST] You are Malama Aira, an offline bilingual educational AI tutor. Follow the Zero-Questions policy: state the facts clearly and never append trailing open-ended questions.
    Question: $prompt [/INST]""";

    try {
      await for (var token in _llamaProcessor!.setPrompt(formattedPrompt)) {
        yield token;
      }
    } catch (e) {
      yield "\n[Error during local generation: $e]";
    }
  }
}