import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Service to connect to the Denuel Voice Bridge Hugging Face Space
class VoiceBridgeService {
  /// Your Hugging Face Space URL
  /// Replace with your actual Space URL after deployment
  final String spaceUrl;
  
  VoiceBridgeService({
    this.spaceUrl = 'https://YOUR_USERNAME-denuel-voice-bridge.hf.space',
  });

  /// Transcribe audio to text
  /// 
  /// [audioBytes] - WAV audio file bytes
  /// Returns the transcribed text
  Future<String> transcribe(Uint8List audioBytes) async {
    try {
      final response = await http.post(
        Uri.parse('$spaceUrl/api/predict'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fn_index': 1, // transcribe_audio function
          'data': [
            {
              'data': 'data:audio/wav;base64,${base64Encode(audioBytes)}',
              'name': 'audio.wav',
            }
          ],
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result['data'][0] as String;
      } else {
        throw Exception('Transcription failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Transcription error: $e');
    }
  }

  /// Synthesize text to speech
  /// 
  /// [text] - Text to synthesize
  /// [language] - Language code (e.g., 'en', 'es', 'fr')
  /// [voiceSampleBytes] - Optional voice sample for cloning
  /// Returns WAV audio bytes
  Future<Uint8List> synthesize(
    String text, {
    String language = 'en',
    Uint8List? voiceSampleBytes,
  }) async {
    try {
      final data = <dynamic>[
        text,
        voiceSampleBytes != null
            ? {
                'data': 'data:audio/wav;base64,${base64Encode(voiceSampleBytes)}',
                'name': 'voice.wav',
              }
            : null,
        _getLanguageName(language),
      ];

      final response = await http.post(
        Uri.parse('$spaceUrl/api/predict'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fn_index': 2, // synthesize_speech function
          'data': data,
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        final audioData = result['data'][0];
        
        if (audioData != null && audioData['data'] != null) {
          final base64Audio = (audioData['data'] as String)
              .split(',')
              .last;
          return base64Decode(base64Audio);
        }
        throw Exception('No audio in response');
      } else {
        throw Exception('Synthesis failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Synthesis error: $e');
    }
  }

  /// Clone voice: transcribe input → synthesize with cloned voice
  /// 
  /// [audioBytes] - Input audio to clone
  /// [language] - Output language
  /// [emotion] - Emotion style (neutral, happy, sad, angry, calm, excited)
  /// Returns a [CloneResult] with transcription and audio
  Future<CloneResult> cloneVoice(
    Uint8List audioBytes, {
    String language = 'en',
    String emotion = 'neutral',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$spaceUrl/api/predict'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fn_index': 0, // clone_voice function
          'data': [
            {
              'data': 'data:audio/wav;base64,${base64Encode(audioBytes)}',
              'name': 'audio.wav',
            },
            _getLanguageName(language),
            emotion,
          ],
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        final data = result['data'];
        
        Uint8List? outputAudio;
        if (data[0] != null && data[0]['data'] != null) {
          final base64Audio = (data[0]['data'] as String).split(',').last;
          outputAudio = base64Decode(base64Audio);
        }
        
        return CloneResult(
          transcription: data[1] as String? ?? '',
          audioBytes: outputAudio,
          status: data[2] as String? ?? '',
        );
      } else {
        throw Exception('Clone failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Clone error: $e');
    }
  }

  /// Compare two voice samples
  /// 
  /// Returns similarity percentage and grade
  Future<String> compareVoices(
    Uint8List audio1Bytes,
    Uint8List audio2Bytes,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$spaceUrl/api/predict'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fn_index': 3, // compare_voices function
          'data': [
            {
              'data': 'data:audio/wav;base64,${base64Encode(audio1Bytes)}',
              'name': 'audio1.wav',
            },
            {
              'data': 'data:audio/wav;base64,${base64Encode(audio2Bytes)}',
              'name': 'audio2.wav',
            },
          ],
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result['data'][0] as String;
      } else {
        throw Exception('Compare failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Compare error: $e');
    }
  }

  /// Check if the Space is available
  Future<bool> healthCheck() async {
    try {
      final response = await http.get(Uri.parse(spaceUrl));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  String _getLanguageName(String code) {
    const languages = {
      'en': 'English',
      'es': 'Spanish',
      'fr': 'French',
      'de': 'German',
      'it': 'Italian',
      'pt': 'Portuguese',
      'pl': 'Polish',
      'tr': 'Turkish',
      'ru': 'Russian',
      'nl': 'Dutch',
      'cs': 'Czech',
      'ar': 'Arabic',
      'zh': 'Chinese',
      'ja': 'Japanese',
      'ko': 'Korean',
      'hi': 'Hindi',
    };
    return languages[code] ?? 'English';
  }

  // ========== STATIC METHODS FOR BACKEND SERVER ==========
  
  /// Base URL for backend server
  /// Change this to your Hugging Face Space URL after deployment:
  /// Example: 'https://YOUR_USERNAME-denuel-voice-bridge.hf.space'
  static String _backendBaseUrl = 'http://localhost:5000';
  
  /// Storage for last processed audio
  static String? _lastProcessedAudioBase64;

  /// Configure the backend URL (call this on app startup)
  static void setBackendUrl(String url) {
    _backendBaseUrl = url;
  }

  /// Get current backend URL
  static String get backendUrl => _backendBaseUrl;

  /// Check if server is running (local or Hugging Face)
  static Future<bool> isServerRunning() async {
    try {
      // For local server
      if (_backendBaseUrl.contains('localhost')) {
        final response = await http.get(Uri.parse('$_backendBaseUrl/health'))
            .timeout(const Duration(seconds: 3));
        return response.statusCode == 200;
      }
      
      // For Hugging Face Space - just check if URL is reachable
      final response = await http.get(Uri.parse(_backendBaseUrl))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Process audio through backend server
  static Future<Map<String, dynamic>> processAudio(String base64Audio, String format) async {
    try {
      // For local Flask server
      if (_backendBaseUrl.contains('localhost')) {
        final response = await http.post(
          Uri.parse('$_backendBaseUrl/process-audio'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'audio_base64': base64Audio,
            'format': format,
          }),
        );

        if (response.statusCode == 200) {
          return jsonDecode(response.body) as Map<String, dynamic>;
        } else {
          throw Exception('Server error: ${response.statusCode}');
        }
      }
      
      // For Hugging Face Space - use Gradio API
      final response = await http.post(
        Uri.parse('$_backendBaseUrl/api/predict'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fn_index': 0,  // process_audio function
          'data': [base64Audio, format],
        }),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['data'] != null && result['data'].isNotEmpty) {
          return result['data'][0] as Map<String, dynamic>;
        }
        throw Exception('Empty response from server');
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Process audio error: $e');
    }
  }

  /// Synthesize text to speech
  static Future<Map<String, dynamic>> synthesizeSpeech(String text, {String language = 'en', String? voiceBase64}) async {
    try {
      // For local Flask server
      if (_backendBaseUrl.contains('localhost')) {
        final response = await http.post(
          Uri.parse('$_backendBaseUrl/process-text'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'text': text,
            'language': language,
            'voice_base64': voiceBase64,
          }),
        );

        if (response.statusCode == 200) {
          return jsonDecode(response.body) as Map<String, dynamic>;
        } else {
          throw Exception('Server error: ${response.statusCode}');
        }
      }
      
      // For Hugging Face Space
      final response = await http.post(
        Uri.parse('$_backendBaseUrl/api/predict'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fn_index': 1,  // synthesize function
          'data': [text, language, voiceBase64 ?? ''],
        }),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['data'] != null && result['data'].isNotEmpty) {
          return result['data'][0] as Map<String, dynamic>;
        }
        throw Exception('Empty response from server');
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Synthesize error: $e');
    }
  }

  /// Store last processed audio for quick playback
  static void setLastProcessedAudioBase64(String? value) {
    _lastProcessedAudioBase64 = value;
  }

  /// Get last processed audio
  static String? getLastProcessedAudioBase64() {
    return _lastProcessedAudioBase64;
  }

  /// Analyze pronunciation and get feedback
  /// Returns metrics, phoneme errors, and suggestions
  static Future<Map<String, dynamic>> analyzePronunciation(
    String base64Audio,
    String format, {
    String? targetText,
  }) async {
    try {
      // For local Flask server
      if (_backendBaseUrl.contains('localhost')) {
        final response = await http.post(
          Uri.parse('$_backendBaseUrl/analyze-pronunciation'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'audio_base64': base64Audio,
            'audio_format': format,
            'target_text': targetText ?? '',
          }),
        ).timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          return jsonDecode(response.body) as Map<String, dynamic>;
        } else {
          throw Exception('Server error: ${response.statusCode}');
        }
      }
      
      // For Hugging Face Space - use Gradio API
      final response = await http.post(
        Uri.parse('$_backendBaseUrl/api/predict'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fn_index': 4, // analyze_pronunciation function
          'data': [base64Audio, format, targetText ?? ''],
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['data'] != null && result['data'].isNotEmpty) {
          return result['data'][0] as Map<String, dynamic>;
        }
        throw Exception('Empty response from server');
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Pronunciation analysis error: $e');
    }
  }
}

/// Result from voice cloning operation
class CloneResult {
  final String transcription;
  final Uint8List? audioBytes;
  final String status;

  CloneResult({
    required this.transcription,
    this.audioBytes,
    required this.status,
  });

  bool get hasAudio => audioBytes != null && audioBytes!.isNotEmpty;
}
