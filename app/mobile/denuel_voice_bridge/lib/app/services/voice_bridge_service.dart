import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;

// Web-specific imports
import 'dart:html' as html;
import 'dart:js' as js;

/// Service to communicate with DENUEL VOICE BRIDGE backend API
class VoiceBridgeService {
  static const String baseUrl = 'http://localhost:5000';
  static bool _modelsReady = false;
  
  /// Check if the backend server is running
  static Future<bool> isServerRunning() async {
    try {
      final response = await _fetch('$baseUrl/health', 'GET', null);
      final data = jsonDecode(response);
      _modelsReady = data['models_loaded'] == true;
      return data['status'] == 'ok';
    } catch (e) {
      print('Server health check failed: $e');
      return false;
    }
  }
  
  /// Check if AI models are loaded
  static bool get modelsReady => _modelsReady;
  
  /// Pre-load AI models to speed up first request
  /// Call this when app starts to avoid delay on first recording
  static Future<bool> warmupModels() async {
    try {
      print('🔥 Warming up AI models...');
      final response = await _fetch('$baseUrl/warmup', 'POST', '{}');
      final data = jsonDecode(response);
      _modelsReady = data['success'] == true;
      return _modelsReady;
    } catch (e) {
      print('Warmup failed: $e');
      return false;
    }
  }
  
  /// Process text and get clear speech audio
  /// Returns: { success, original_text, normalized_text, audio_base64 }
  static Future<Map<String, dynamic>> processText(String text) async {
    try {
      final response = await _fetch(
        '$baseUrl/process-text',
        'POST',
        jsonEncode({'text': text}),
      );
      return jsonDecode(response);
    } catch (e) {
      print('Error processing text: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
  
  /// Process audio recording and get clear speech
  /// audioBase64: base64-encoded audio data
  /// audioFormat: 'webm', 'wav', etc.
  /// Returns: { success, recognized_text, normalized_text, audio_base64 }
  static Future<Map<String, dynamic>> processAudio(
    String audioBase64, 
    String audioFormat,
  ) async {
    try {
      final response = await _fetch(
        '$baseUrl/process-audio',
        'POST',
        jsonEncode({
          'audio_base64': audioBase64,
          'audio_format': audioFormat,
        }),
      );
      return jsonDecode(response);
    } catch (e) {
      print('Error processing audio: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
  
  /// Get phrase memory
  static Future<Map<String, dynamic>> getPhraseMemory() async {
    try {
      final response = await _fetch('$baseUrl/phrase-memory', 'GET', null);
      return jsonDecode(response);
    } catch (e) {
      print('Error getting phrase memory: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
  
  /// Set user name in phrase memory
  static Future<Map<String, dynamic>> setUserName(String name) async {
    try {
      final response = await _fetch(
        '$baseUrl/phrase-memory',
        'POST',
        jsonEncode({'action': 'set_name', 'name': name}),
      );
      return jsonDecode(response);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
  
  /// Add name correction to phrase memory
  static Future<Map<String, dynamic>> addNameCorrection(
    String heard, 
    String correct,
  ) async {
    try {
      final response = await _fetch(
        '$baseUrl/phrase-memory',
        'POST',
        jsonEncode({'action': 'add_name', 'heard': heard, 'correct': correct}),
      );
      return jsonDecode(response);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
  
  /// Add phrase correction to phrase memory
  static Future<Map<String, dynamic>> addPhraseCorrection(
    String heard, 
    String correct,
  ) async {
    try {
      final response = await _fetch(
        '$baseUrl/phrase-memory',
        'POST',
        jsonEncode({'action': 'add_phrase', 'heard': heard, 'correct': correct}),
      );
      return jsonDecode(response);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
  
  /// Get available voice samples
  static Future<Map<String, dynamic>> getVoiceSamples() async {
    try {
      final response = await _fetch('$baseUrl/voice-samples', 'GET', null);
      return jsonDecode(response);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
  
  /// Convert Blob to base64 string (web only)
  static Future<String> blobToBase64(html.Blob blob) async {
    final reader = html.FileReader();
    reader.readAsDataUrl(blob);
    await reader.onLoadEnd.first;
    
    final result = reader.result as String;
    // Remove data URL prefix (e.g., "data:audio/webm;base64,")
    final base64Index = result.indexOf('base64,');
    if (base64Index != -1) {
      return result.substring(base64Index + 7);
    }
    return result;
  }
  
  /// Play base64 audio (web only)
  static void playBase64Audio(String base64Audio, String format) {
    if (!kIsWeb) return;
    
    final dataUrl = 'data:audio/$format;base64,$base64Audio';
    final audio = html.AudioElement(dataUrl);
    audio.play();
  }
  
  /// Internal fetch helper for web
  static Future<String> _fetch(String url, String method, String? body) async {
    if (!kIsWeb) {
      throw UnsupportedError('VoiceBridgeService only works on web');
    }
    
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    
    final request = await html.HttpRequest.request(
      url,
      method: method,
      requestHeaders: headers,
      sendData: body,
    );
    
    return request.responseText ?? '';
  }
}
