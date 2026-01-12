import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

/// App settings service with persistent storage
class AppSettingsService extends ChangeNotifier {
  static const String _keyMode = 'user_mode';
  static const String _keyProfile = 'user_profile';
  static const String _keyPrivacyMode = 'privacy_offline_mode';
  static const String _keyFirstLaunch = 'first_launch';
  static const String _keyGameProgress = 'game_progress';
  
  SharedPreferences? _prefs;
  
  UserMode _currentMode = UserMode.child;
  UserProfile? _userProfile;
  bool _isOfflineMode = false;
  bool _isFirstLaunch = true;
  GameProgress _gameProgress = GameProgress();
  
  // Getters
  UserMode get currentMode => _currentMode;
  UserProfile? get userProfile => _userProfile;
  bool get isOfflineMode => _isOfflineMode;
  bool get isFirstLaunch => _isFirstLaunch;
  GameProgress get gameProgress => _gameProgress;
  bool get isAdultMode => _currentMode == UserMode.adult;
  bool get isChildMode => _currentMode == UserMode.child;

  /// Initialize the service
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadSettings();
  }

  Future<void> _loadSettings() async {
    if (_prefs == null) return;

    // Load mode
    final modeString = _prefs!.getString(_keyMode);
    if (modeString != null) {
      _currentMode = UserMode.values.firstWhere(
        (m) => m.name == modeString,
        orElse: () => UserMode.child,
      );
    }

    // Load profile
    final profileJson = _prefs!.getString(_keyProfile);
    if (profileJson != null) {
      try {
        _userProfile = UserProfile.fromJson(jsonDecode(profileJson));
      } catch (e) {
        debugPrint('Error loading profile: $e');
      }
    }

    // Load privacy mode
    _isOfflineMode = _prefs!.getBool(_keyPrivacyMode) ?? false;
    
    // Load first launch flag
    _isFirstLaunch = _prefs!.getBool(_keyFirstLaunch) ?? true;

    // Load game progress
    final gameJson = _prefs!.getString(_keyGameProgress);
    if (gameJson != null) {
      try {
        _gameProgress = GameProgress.fromJson(jsonDecode(gameJson));
      } catch (e) {
        debugPrint('Error loading game progress: $e');
      }
    }

    notifyListeners();
  }

  /// Set user mode (Adult/Child)
  Future<void> setMode(UserMode mode) async {
    _currentMode = mode;
    await _prefs?.setString(_keyMode, mode.name);
    notifyListeners();
  }

  /// Update user profile
  Future<void> updateProfile(UserProfile profile) async {
    _userProfile = profile;
    await _prefs?.setString(_keyProfile, jsonEncode(profile.toJson()));
    notifyListeners();
  }

  /// Create initial profile
  Future<void> createProfile({
    required String name,
    required UserMode mode,
    int age = 0,
  }) async {
    _userProfile = UserProfile(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      preferredMode: mode,
      age: age,
    );
    _currentMode = mode;
    
    await _prefs?.setString(_keyProfile, jsonEncode(_userProfile!.toJson()));
    await _prefs?.setString(_keyMode, mode.name);
    await _prefs?.setBool(_keyFirstLaunch, false);
    _isFirstLaunch = false;
    
    notifyListeners();
  }

  /// Toggle offline/privacy mode
  Future<void> setOfflineMode(bool enabled) async {
    _isOfflineMode = enabled;
    await _prefs?.setBool(_keyPrivacyMode, enabled);
    notifyListeners();
  }

  /// Update game progress
  Future<void> updateGameProgress(GameProgress progress) async {
    _gameProgress = progress;
    await _prefs?.setString(_keyGameProgress, jsonEncode(progress.toJson()));
    notifyListeners();
  }

  /// Add experience points
  Future<void> addExperience(int xp) async {
    int newXp = _gameProgress.experience + xp;
    int newLevel = _gameProgress.level;
    int newXpToNext = _gameProgress.experienceToNextLevel;

    while (newXp >= newXpToNext) {
      newXp -= newXpToNext;
      newLevel++;
      newXpToNext = (newXpToNext * 1.5).round();
    }

    _gameProgress = _gameProgress.copyWith(
      experience: newXp,
      level: newLevel,
      experienceToNextLevel: newXpToNext,
    );

    await _prefs?.setString(_keyGameProgress, jsonEncode(_gameProgress.toJson()));
    notifyListeners();
  }

  /// Add stars
  Future<void> addStars(int count) async {
    _gameProgress = _gameProgress.copyWith(
      stars: _gameProgress.stars + count,
    );
    await _prefs?.setString(_keyGameProgress, jsonEncode(_gameProgress.toJson()));
    notifyListeners();
  }

  /// Record completed session
  Future<void> recordSession(Duration duration) async {
    if (_userProfile == null) return;

    final now = DateTime.now();
    final lastSession = _userProfile!.lastSessionDate;
    
    int newStreak = _userProfile!.currentStreak;
    if (lastSession != null) {
      final diff = now.difference(lastSession).inDays;
      if (diff == 1) {
        newStreak++;
      } else if (diff > 1) {
        newStreak = 1;
      }
    } else {
      newStreak = 1;
    }

    _userProfile = _userProfile!.copyWith(
      totalSessions: _userProfile!.totalSessions + 1,
      totalMinutes: _userProfile!.totalMinutes + duration.inMinutes,
      currentStreak: newStreak,
      longestStreak: newStreak > _userProfile!.longestStreak 
          ? newStreak 
          : _userProfile!.longestStreak,
      lastSessionDate: now,
    );

    await _prefs?.setString(_keyProfile, jsonEncode(_userProfile!.toJson()));
    notifyListeners();
  }

  /// Clear all data
  Future<void> clearAllData() async {
    await _prefs?.clear();
    _currentMode = UserMode.child;
    _userProfile = null;
    _isOfflineMode = false;
    _isFirstLaunch = true;
    _gameProgress = GameProgress();
    notifyListeners();
  }
}
