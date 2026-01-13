import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

/// Service for managing practice sessions
class SessionService extends ChangeNotifier {
  static const String _keySessions = 'practice_sessions';
  static const int _maxStoredSessions = 100;
  
  SharedPreferences? _prefs;
  List<PracticeSession> _sessions = [];
  PracticeSession? _currentSession;
  
  // Getters
  List<PracticeSession> get sessions => List.unmodifiable(_sessions);
  List<PracticeSession> get allSessions => List.unmodifiable(_sessions);
  PracticeSession? get currentSession => _currentSession;
  bool get hasActiveSession => _currentSession != null;
  
  List<PracticeSession> get recentSessions => 
      _sessions.take(10).toList();
  
  List<PracticeSession> get completedSessions => 
      _sessions.where((s) => s.completed).toList();

  /// Initialize the service
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadSessions();
  }

  Future<void> _loadSessions() async {
    if (_prefs == null) return;

    final sessionsJson = _prefs!.getString(_keySessions);
    if (sessionsJson != null) {
      try {
        final List<dynamic> list = jsonDecode(sessionsJson);
        _sessions = list.map((j) => PracticeSession.fromJson(j)).toList();
      } catch (e) {
        debugPrint('Error loading sessions: $e');
      }
    }
    notifyListeners();
  }

  Future<void> _saveSessions() async {
    // Keep only recent sessions
    if (_sessions.length > _maxStoredSessions) {
      _sessions = _sessions.take(_maxStoredSessions).toList();
    }
    
    await _prefs?.setString(
      _keySessions,
      jsonEncode(_sessions.map((s) => s.toJson()).toList()),
    );
  }

  /// Start a new session
  PracticeSession startSession({
    required UserMode mode,
    required SessionType type,
    ScenarioType? scenario,
  }) {
    _currentSession = PracticeSession(
      id: _generateId(),
      mode: mode,
      type: type,
      scenario: scenario,
      startTime: DateTime.now(),
      duration: Duration.zero,
    );
    notifyListeners();
    return _currentSession!;
  }

  /// Update current session with metrics
  void updateSessionMetrics(SpeechMetrics metrics) {
    if (_currentSession == null) return;

    final history = List<SpeechMetrics>.from(_currentSession!.metricsHistory)
      ..add(metrics);

    _currentSession = _currentSession!.copyWith(
      metricsHistory: history,
      duration: DateTime.now().difference(_currentSession!.startTime),
    );
    notifyListeners();
  }

  /// End current session
  Future<PracticeSession?> endSession({
    SpeechMetrics? finalMetrics,
    String? audioPath,
    String? processedAudioBase64,
    String? processedAudioFormat,
    String? transcript,
    List<String>? notes,
  }) async {
    if (_currentSession == null) return null;

    final now = DateTime.now();
    _currentSession = _currentSession!.copyWith(
      endTime: now,
      duration: now.difference(_currentSession!.startTime),
      finalMetrics: finalMetrics,
      audioPath: audioPath,
      processedAudioBase64: processedAudioBase64,
      processedAudioFormat: processedAudioFormat,
      transcript: transcript,
      notes: notes ?? [],
      completed: true,
    );

    _sessions.insert(0, _currentSession!);
    await _saveSessions();

    final completedSession = _currentSession;
    _currentSession = null;
    notifyListeners();

    return completedSession;
  }

  /// Cancel current session
  void cancelSession() {
    _currentSession = null;
    notifyListeners();
  }

  /// Get sessions by mode
  List<PracticeSession> getSessionsByMode(UserMode mode) {
    return _sessions.where((s) => s.mode == mode).toList();
  }

  /// Get sessions by date range
  List<PracticeSession> getSessionsByDateRange(DateTime start, DateTime end) {
    return _sessions.where((s) =>
        s.startTime.isAfter(start) && s.startTime.isBefore(end)).toList();
  }

  /// Get sessions for today
  List<PracticeSession> get todaySessions {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    return _sessions.where((s) => s.startTime.isAfter(startOfDay)).toList();
  }

  /// Get sessions for this week
  List<PracticeSession> get weekSessions {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final start = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    return _sessions.where((s) => s.startTime.isAfter(start)).toList();
  }

  /// Calculate average score for sessions
  double getAverageScore(List<PracticeSession> sessions) {
    final withMetrics = sessions.where((s) => s.finalMetrics != null);
    if (withMetrics.isEmpty) return 0;

    final total = withMetrics.fold<double>(
      0,
      (sum, s) => sum + s.finalMetrics!.overallScore,
    );
    return total / withMetrics.length;
  }

  /// Get total practice time
  Duration getTotalPracticeTime([List<PracticeSession>? sessionList]) {
    final list = sessionList ?? _sessions;
    return list.fold<Duration>(
      Duration.zero,
      (total, s) => total + s.duration,
    );
  }

  /// Delete a session
  Future<void> deleteSession(String id) async {
    _sessions.removeWhere((s) => s.id == id);
    await _saveSessions();
    notifyListeners();
  }

  /// Update a session's notes
  Future<void> updateSessionNotes(String id, List<String> notes) async {
    final index = _sessions.indexWhere((s) => s.id == id);
    if (index != -1) {
      _sessions[index] = _sessions[index].copyWith(notes: notes);
      await _saveSessions();
      notifyListeners();
    }
  }

  /// Add a note to a session
  Future<void> addNoteToSession(String id, String note) async {
    final index = _sessions.indexWhere((s) => s.id == id);
    if (index != -1) {
      final currentNotes = List<String>.from(_sessions[index].notes);
      currentNotes.add(note);
      _sessions[index] = _sessions[index].copyWith(notes: currentNotes);
      await _saveSessions();
      notifyListeners();
    }
  }

  /// Clear all sessions
  Future<void> clearAllSessions() async {
    _sessions.clear();
    _currentSession = null;
    await _prefs?.remove(_keySessions);
    notifyListeners();
  }

  String _generateId() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomPart = random.nextInt(99999).toString().padLeft(5, '0');
    return '${timestamp}_$randomPart';
  }
}
