/// Speech metrics data model for analysis feedback
class SpeechMetrics {
  final double clarityScore; // 0-100
  final double nasalityScore; // 0-100 (lower is better for most cases)
  final double pacingScore; // syllables per second
  final double breathControlScore; // 0-100
  final double overallScore; // 0-100
  final List<PhonemeError> phonemeErrors;
  final List<String> suggestions;
  final DateTime timestamp;

  SpeechMetrics({
    required this.clarityScore,
    required this.nasalityScore,
    required this.pacingScore,
    required this.breathControlScore,
    required this.overallScore,
    required this.phonemeErrors,
    required this.suggestions,
    required this.timestamp,
  });

  factory SpeechMetrics.empty() => SpeechMetrics(
        clarityScore: 0,
        nasalityScore: 0,
        pacingScore: 0,
        breathControlScore: 0,
        overallScore: 0,
        phonemeErrors: [],
        suggestions: [],
        timestamp: DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'clarityScore': clarityScore,
        'nasalityScore': nasalityScore,
        'pacingScore': pacingScore,
        'breathControlScore': breathControlScore,
        'overallScore': overallScore,
        'phonemeErrors': phonemeErrors.map((e) => e.toJson()).toList(),
        'suggestions': suggestions,
        'timestamp': timestamp.toIso8601String(),
      };

  factory SpeechMetrics.fromJson(Map<String, dynamic> json) => SpeechMetrics(
        clarityScore: (json['clarityScore'] as num).toDouble(),
        nasalityScore: (json['nasalityScore'] as num).toDouble(),
        pacingScore: (json['pacingScore'] as num).toDouble(),
        breathControlScore: (json['breathControlScore'] as num).toDouble(),
        overallScore: (json['overallScore'] as num).toDouble(),
        phonemeErrors: (json['phonemeErrors'] as List)
            .map((e) => PhonemeError.fromJson(e))
            .toList(),
        suggestions: List<String>.from(json['suggestions']),
        timestamp: DateTime.parse(json['timestamp']),
      );

  /// Get severity level for a score
  static MetricSeverity getSeverity(double score) {
    if (score >= 80) return MetricSeverity.good;
    if (score >= 60) return MetricSeverity.moderate;
    return MetricSeverity.needsWork;
  }
}

/// Phoneme error details
class PhonemeError {
  final String phoneme;
  final String expected;
  final String actual;
  final int position;
  final double confidence;

  PhonemeError({
    required this.phoneme,
    required this.expected,
    required this.actual,
    required this.position,
    required this.confidence,
  });

  Map<String, dynamic> toJson() => {
        'phoneme': phoneme,
        'expected': expected,
        'actual': actual,
        'position': position,
        'confidence': confidence,
      };

  factory PhonemeError.fromJson(Map<String, dynamic> json) => PhonemeError(
        phoneme: json['phoneme'],
        expected: json['expected'],
        actual: json['actual'],
        position: json['position'],
        confidence: (json['confidence'] as num).toDouble(),
      );
}

/// Severity levels for metrics
enum MetricSeverity {
  good,
  moderate,
  needsWork,
}

extension MetricSeverityExtension on MetricSeverity {
  String get label {
    switch (this) {
      case MetricSeverity.good:
        return 'Good';
      case MetricSeverity.moderate:
        return 'Moderate';
      case MetricSeverity.needsWork:
        return 'Needs Work';
    }
  }
}
