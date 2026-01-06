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
