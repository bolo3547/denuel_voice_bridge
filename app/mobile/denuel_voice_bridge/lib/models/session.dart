import 'speech_metrics.dart';
import 'user_mode.dart';

/// Practice session data model
class PracticeSession {
  final String id;
  final UserMode mode;
  final SessionType type;
  final ScenarioType? scenario;
  final DateTime startTime;
  final DateTime? endTime;
  final Duration duration;
  final List<SpeechMetrics> metricsHistory;
  final SpeechMetrics? finalMetrics;
  final String? audioPath;
  final String? transcript;
  final List<String> notes;
  final bool completed;

  PracticeSession({
    required this.id,
    required this.mode,
    required this.type,
    this.scenario,
    required this.startTime,
    this.endTime,
    required this.duration,
    this.metricsHistory = const [],
    this.finalMetrics,
    this.audioPath,
    this.transcript,
    this.notes = const [],
    this.completed = false,
  });

  PracticeSession copyWith({
    String? id,
    UserMode? mode,
    SessionType? type,
    ScenarioType? scenario,
    DateTime? startTime,
    DateTime? endTime,
    Duration? duration,
    List<SpeechMetrics>? metricsHistory,
    SpeechMetrics? finalMetrics,
    String? audioPath,
    String? transcript,
    List<String>? notes,
    bool? completed,
  }) {
    return PracticeSession(
      id: id ?? this.id,
      mode: mode ?? this.mode,
      type: type ?? this.type,
      scenario: scenario ?? this.scenario,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      duration: duration ?? this.duration,
      metricsHistory: metricsHistory ?? this.metricsHistory,
      finalMetrics: finalMetrics ?? this.finalMetrics,
      audioPath: audioPath ?? this.audioPath,
      transcript: transcript ?? this.transcript,
      notes: notes ?? this.notes,
      completed: completed ?? this.completed,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'mode': mode.name,
        'type': type.name,
        'scenario': scenario?.name,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
        'duration': duration.inSeconds,
        'metricsHistory': metricsHistory.map((m) => m.toJson()).toList(),
        'finalMetrics': finalMetrics?.toJson(),
        'audioPath': audioPath,
        'transcript': transcript,
        'notes': notes,
        'completed': completed,
      };

  factory PracticeSession.fromJson(Map<String, dynamic> json) => PracticeSession(
        id: json['id'],
        mode: UserMode.values.firstWhere((e) => e.name == json['mode']),
        type: SessionType.values.firstWhere((e) => e.name == json['type']),
        scenario: json['scenario'] != null
            ? ScenarioType.values.firstWhere((e) => e.name == json['scenario'])
            : null,
        startTime: DateTime.parse(json['startTime']),
        endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
        duration: Duration(seconds: json['duration']),
        metricsHistory: (json['metricsHistory'] as List)
            .map((m) => SpeechMetrics.fromJson(m))
            .toList(),
        finalMetrics: json['finalMetrics'] != null
            ? SpeechMetrics.fromJson(json['finalMetrics'])
            : null,
        audioPath: json['audioPath'],
        transcript: json['transcript'],
        notes: List<String>.from(json['notes'] ?? []),
        completed: json['completed'] ?? false,
      );
}

/// Session types
enum SessionType {
  freePractice,
  scenario,
  breathExercise,
  phonemeExercise,
  dailyTherapy,
  game,
}

extension SessionTypeExtension on SessionType {
  String get displayName {
    switch (this) {
      case SessionType.freePractice:
        return 'Free Practice';
      case SessionType.scenario:
        return 'Scenario Practice';
      case SessionType.breathExercise:
        return 'Breath Exercise';
      case SessionType.phonemeExercise:
        return 'Phoneme Exercise';
      case SessionType.dailyTherapy:
        return 'Daily Therapy';
      case SessionType.game:
        return 'Speech Game';
    }
  }

  String get icon {
    switch (this) {
      case SessionType.freePractice:
        return '🎤';
      case SessionType.scenario:
        return '🎭';
      case SessionType.breathExercise:
        return '🌬️';
      case SessionType.phonemeExercise:
        return '🔤';
      case SessionType.dailyTherapy:
        return '📅';
      case SessionType.game:
        return '🎮';
    }
  }
}

/// Scenario types for adult mode
enum ScenarioType {
  jobInterview,
  phoneCall,
  publicSpeaking,
  casualConversation,
  medicalAppointment,
  presentation,
  ordering,
}

extension ScenarioTypeExtension on ScenarioType {
  String get displayName {
    switch (this) {
      case ScenarioType.jobInterview:
        return 'Job Interview';
      case ScenarioType.phoneCall:
        return 'Phone Call';
      case ScenarioType.publicSpeaking:
        return 'Public Speaking';
      case ScenarioType.casualConversation:
        return 'Casual Conversation';
      case ScenarioType.medicalAppointment:
        return 'Medical Appointment';
      case ScenarioType.presentation:
        return 'Presentation';
      case ScenarioType.ordering:
        return 'Ordering Food/Service';
    }
  }

  String get description {
    switch (this) {
      case ScenarioType.jobInterview:
        return 'Practice answering common interview questions with confidence';
      case ScenarioType.phoneCall:
        return 'Improve clarity for phone conversations';
      case ScenarioType.publicSpeaking:
        return 'Build confidence for speeches and presentations';
      case ScenarioType.casualConversation:
        return 'Practice everyday social interactions';
      case ScenarioType.medicalAppointment:
        return 'Communicate clearly with healthcare providers';
      case ScenarioType.presentation:
        return 'Deliver professional presentations effectively';
      case ScenarioType.ordering:
        return 'Practice ordering at restaurants and services';
    }
  }

  String get icon {
    switch (this) {
      case ScenarioType.jobInterview:
        return '💼';
      case ScenarioType.phoneCall:
        return '📞';
      case ScenarioType.publicSpeaking:
        return '🎤';
      case ScenarioType.casualConversation:
        return '💬';
      case ScenarioType.medicalAppointment:
        return '🏥';
      case ScenarioType.presentation:
        return '📊';
      case ScenarioType.ordering:
        return '🍽️';
    }
  }

  List<String> get samplePrompts {
    switch (this) {
      case ScenarioType.jobInterview:
        return [
          'Tell me about yourself.',
          'What are your greatest strengths?',
          'Why do you want to work here?',
          'Describe a challenge you overcame.',
          'Where do you see yourself in 5 years?',
        ];
      case ScenarioType.phoneCall:
        return [
          'Hello, this is [name] calling about...',
          'I\'m calling to schedule an appointment.',
          'Could you please repeat that?',
          'Let me confirm the details...',
        ];
      case ScenarioType.publicSpeaking:
        return [
          'Good morning everyone, today I will talk about...',
          'Thank you for having me here today.',
          'In conclusion, I believe that...',
        ];
      case ScenarioType.casualConversation:
        return [
          'Hi, how are you doing today?',
          'What do you think about...',
          'That\'s interesting, tell me more.',
        ];
      case ScenarioType.medicalAppointment:
        return [
          'I\'ve been experiencing...',
          'The pain is located here...',
          'How often should I take this medication?',
        ];
      case ScenarioType.presentation:
        return [
          'Let me walk you through the key points...',
          'As you can see from this data...',
          'Are there any questions so far?',
        ];
      case ScenarioType.ordering:
        return [
          'I\'d like to order the...',
          'Could I have this without...',
          'May I have the check, please?',
        ];
    }
  }
}
