import 'user_mode.dart';

/// User profile for personalization and progress tracking
class UserProfile {
  final String id;
  final String? name;
  final UserMode preferredMode;
  final int age;
  final UserType userType;
  final List<String> targetPhonemes;
  final List<String> achievements;
  final int totalSessions;
  final int totalMinutes;
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastSessionDate;
  final Map<String, dynamic> settings;
  final TherapistInfo? therapist;

  UserProfile({
    required this.id,
    this.name,
    this.preferredMode = UserMode.child,
    this.age = 0,
    this.userType = UserType.selfUser,
    this.targetPhonemes = const [],
    this.achievements = const [],
    this.totalSessions = 0,
    this.totalMinutes = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastSessionDate,
    this.settings = const {},
    this.therapist,
  });

  UserProfile copyWith({
    String? id,
    String? name,
    UserMode? preferredMode,
    int? age,
    UserType? userType,
    List<String>? targetPhonemes,
    List<String>? achievements,
    int? totalSessions,
    int? totalMinutes,
    int? currentStreak,
    int? longestStreak,
    DateTime? lastSessionDate,
    Map<String, dynamic>? settings,
    TherapistInfo? therapist,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      preferredMode: preferredMode ?? this.preferredMode,
      age: age ?? this.age,
      userType: userType ?? this.userType,
      targetPhonemes: targetPhonemes ?? this.targetPhonemes,
      achievements: achievements ?? this.achievements,
      totalSessions: totalSessions ?? this.totalSessions,
      totalMinutes: totalMinutes ?? this.totalMinutes,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastSessionDate: lastSessionDate ?? this.lastSessionDate,
      settings: settings ?? this.settings,
      therapist: therapist ?? this.therapist,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'preferredMode': preferredMode.name,
        'age': age,
        'userType': userType.name,
        'targetPhonemes': targetPhonemes,
        'achievements': achievements,
        'totalSessions': totalSessions,
        'totalMinutes': totalMinutes,
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'lastSessionDate': lastSessionDate?.toIso8601String(),
        'settings': settings,
        'therapist': therapist?.toJson(),
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'],
        name: json['name'],
        preferredMode: UserMode.values.firstWhere(
          (e) => e.name == json['preferredMode'],
          orElse: () => UserMode.child,
        ),
        age: json['age'] ?? 0,
        userType: UserType.values.firstWhere(
          (e) => e.name == json['userType'],
          orElse: () => UserType.selfUser,
        ),
        targetPhonemes: List<String>.from(json['targetPhonemes'] ?? []),
        achievements: List<String>.from(json['achievements'] ?? []),
        totalSessions: json['totalSessions'] ?? 0,
        totalMinutes: json['totalMinutes'] ?? 0,
        currentStreak: json['currentStreak'] ?? 0,
        longestStreak: json['longestStreak'] ?? 0,
        lastSessionDate: json['lastSessionDate'] != null
            ? DateTime.parse(json['lastSessionDate'])
            : null,
        settings: Map<String, dynamic>.from(json['settings'] ?? {}),
        therapist: json['therapist'] != null
            ? TherapistInfo.fromJson(json['therapist'])
            : null,
      );
}

/// User type for different roles
enum UserType {
  selfUser,
  parent,
  therapist,
  clinician,
}

extension UserTypeExtension on UserType {
  String get displayName {
    switch (this) {
      case UserType.selfUser:
        return 'Self';
      case UserType.parent:
        return 'Parent/Guardian';
      case UserType.therapist:
        return 'Therapist';
      case UserType.clinician:
        return 'Clinician';
    }
  }
}

/// Therapist/clinician info for connected care
class TherapistInfo {
  final String id;
  final String name;
  final String? email;
  final String? clinic;
  final bool shareReports;

  TherapistInfo({
    required this.id,
    required this.name,
    this.email,
    this.clinic,
    this.shareReports = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'clinic': clinic,
        'shareReports': shareReports,
      };

  factory TherapistInfo.fromJson(Map<String, dynamic> json) => TherapistInfo(
        id: json['id'],
        name: json['name'],
        email: json['email'],
        clinic: json['clinic'],
        shareReports: json['shareReports'] ?? false,
      );
}
