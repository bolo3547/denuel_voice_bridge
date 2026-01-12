import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/models.dart';

/// Service for analyzing speech and generating metrics
/// This is a local simulation - in production, connect to real ASR/analysis
class SpeechMetricsService extends ChangeNotifier {
  bool _isAnalyzing = false;
  SpeechMetrics? _lastMetrics;
  
  bool get isAnalyzing => _isAnalyzing;
  SpeechMetrics? get lastMetrics => _lastMetrics;

  /// Analyze speech audio and return metrics
  /// In production, this would connect to your voice_bridge backend
  Future<SpeechMetrics> analyzeAudio({
    required String audioPath,
    String? targetText,
    List<String>? targetPhonemes,
  }) async {
    _isAnalyzing = true;
    notifyListeners();

    try {
      // Simulate processing time
      await Future.delayed(const Duration(milliseconds: 1500));

      // Generate simulated metrics
      // In production, replace with real analysis from your backend
      final metrics = _generateSimulatedMetrics(targetPhonemes);
      
      _lastMetrics = metrics;
      _isAnalyzing = false;
      notifyListeners();

      return metrics;
    } catch (e) {
      _isAnalyzing = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Analyze in real-time (for live feedback)
  Stream<SpeechMetrics> analyzeRealTime(Stream<List<int>> audioStream) async* {
    // In production, stream audio to backend and yield metrics
    // This is a simulation
    await for (final _ in audioStream) {
      await Future.delayed(const Duration(milliseconds: 500));
      yield _generateSimulatedMetrics(null);
    }
  }

  /// Generate feedback suggestions based on metrics
  List<String> generateSuggestions(SpeechMetrics metrics) {
    final suggestions = <String>[];

    if (metrics.clarityScore < 70) {
      suggestions.add('Try speaking more slowly and clearly. Focus on pronouncing each syllable.');
    }
    if (metrics.nasalityScore > 60) {
      suggestions.add('Practice breath control exercises to reduce nasal resonance.');
    }
    if (metrics.pacingScore < 2.5) {
      suggestions.add('Your pace is a bit fast. Try pausing between sentences.');
    }
    if (metrics.pacingScore > 4.5) {
      suggestions.add('Try to speak a bit faster to maintain natural flow.');
    }
    if (metrics.breathControlScore < 70) {
      suggestions.add('Practice diaphragmatic breathing before speaking.');
    }

    if (metrics.phonemeErrors.isNotEmpty) {
      final commonErrors = metrics.phonemeErrors
          .map((e) => e.phoneme)
          .toSet()
          .take(3);
      suggestions.add(
        'Focus on these sounds: ${commonErrors.join(", ")}',
      );
    }

    if (suggestions.isEmpty) {
      suggestions.add('Great job! Your speech is clear and well-paced.');
    }

    return suggestions;
  }

  /// Get severity color for a metric
  MetricSeverity getScoreSeverity(double score) {
    return SpeechMetrics.getSeverity(score);
  }

  /// Calculate overall improvement from session history
  double calculateImprovement(List<SpeechMetrics> history) {
    if (history.length < 2) return 0;

    final recent = history.take(5).map((m) => m.overallScore).reduce((a, b) => a + b) / 
                   history.take(5).length;
    final older = history.skip(5).take(5);
    if (older.isEmpty) return 0;
    
    final olderAvg = older.map((m) => m.overallScore).reduce((a, b) => a + b) / 
                     older.length;

    return recent - olderAvg;
  }

  /// Simulate metrics for demo purposes
  /// Replace this with real analysis in production
  SpeechMetrics _generateSimulatedMetrics(List<String>? targetPhonemes) {
    final random = Random();
    
    // Generate realistic-looking scores
    final clarity = 60.0 + random.nextDouble() * 35;
    final nasality = 20.0 + random.nextDouble() * 40;
    final pacing = 2.5 + random.nextDouble() * 2;
    final breath = 55.0 + random.nextDouble() * 40;
    
    // Calculate overall
    final overall = (clarity * 0.35 + 
                    (100 - nasality) * 0.25 + 
                    (pacing > 3 && pacing < 4 ? 90 : 70) * 0.2 +
                    breath * 0.2);

    // Generate some phoneme errors
    final possibleErrors = targetPhonemes ?? ['s', 'r', 'l', 'th', 'ch'];
    final errorCount = random.nextInt(3);
    final errors = <PhonemeError>[];
    
    for (int i = 0; i < errorCount; i++) {
      final phoneme = possibleErrors[random.nextInt(possibleErrors.length)];
      errors.add(PhonemeError(
        phoneme: phoneme,
        expected: phoneme,
        actual: _getSubstitution(phoneme),
        position: random.nextInt(50),
        confidence: 0.6 + random.nextDouble() * 0.3,
      ));
    }

    final suggestions = <String>[];
    if (clarity < 75) suggestions.add('Focus on clear articulation');
    if (nasality > 50) suggestions.add('Try breath exercises for nasal control');
    if (breath < 70) suggestions.add('Practice diaphragmatic breathing');

    return SpeechMetrics(
      clarityScore: clarity,
      nasalityScore: nasality,
      pacingScore: pacing,
      breathControlScore: breath,
      overallScore: overall,
      phonemeErrors: errors,
      suggestions: suggestions,
      timestamp: DateTime.now(),
    );
  }

  String _getSubstitution(String phoneme) {
    const substitutions = {
      's': 'th',
      'r': 'w',
      'l': 'w',
      'th': 's',
      'ch': 'sh',
      'sh': 's',
      'z': 's',
      'v': 'b',
      'f': 'p',
    };
    return substitutions[phoneme] ?? phoneme;
  }
}
