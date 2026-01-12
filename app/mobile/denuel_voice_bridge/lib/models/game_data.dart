/// Game and rewards data for child mode
class GameProgress {
  final int level;
  final int experience;
  final int experienceToNextLevel;
  final List<Achievement> achievements;
  final List<Sticker> stickers;
  final int stars;
  final int coins;
  final List<String> unlockedAvatars;
  final String currentAvatar;

  GameProgress({
    this.level = 1,
    this.experience = 0,
    this.experienceToNextLevel = 100,
    this.achievements = const [],
    this.stickers = const [],
    this.stars = 0,
    this.coins = 0,
    this.unlockedAvatars = const ['default'],
    this.currentAvatar = 'default',
  });

  double get levelProgress => experience / experienceToNextLevel;

  GameProgress copyWith({
    int? level,
    int? experience,
    int? experienceToNextLevel,
    List<Achievement>? achievements,
    List<Sticker>? stickers,
    int? stars,
    int? coins,
    List<String>? unlockedAvatars,
    String? currentAvatar,
  }) {
    return GameProgress(
      level: level ?? this.level,
      experience: experience ?? this.experience,
      experienceToNextLevel: experienceToNextLevel ?? this.experienceToNextLevel,
      achievements: achievements ?? this.achievements,
      stickers: stickers ?? this.stickers,
      stars: stars ?? this.stars,
      coins: coins ?? this.coins,
      unlockedAvatars: unlockedAvatars ?? this.unlockedAvatars,
      currentAvatar: currentAvatar ?? this.currentAvatar,
    );
  }

  Map<String, dynamic> toJson() => {
        'level': level,
        'experience': experience,
        'experienceToNextLevel': experienceToNextLevel,
        'achievements': achievements.map((a) => a.toJson()).toList(),
        'stickers': stickers.map((s) => s.toJson()).toList(),
        'stars': stars,
        'coins': coins,
        'unlockedAvatars': unlockedAvatars,
        'currentAvatar': currentAvatar,
      };

  factory GameProgress.fromJson(Map<String, dynamic> json) => GameProgress(
        level: json['level'] ?? 1,
        experience: json['experience'] ?? 0,
        experienceToNextLevel: json['experienceToNextLevel'] ?? 100,
        achievements: (json['achievements'] as List?)
                ?.map((a) => Achievement.fromJson(a))
                .toList() ??
            [],
        stickers: (json['stickers'] as List?)
                ?.map((s) => Sticker.fromJson(s))
                .toList() ??
            [],
        stars: json['stars'] ?? 0,
        coins: json['coins'] ?? 0,
        unlockedAvatars: List<String>.from(json['unlockedAvatars'] ?? ['default']),
        currentAvatar: json['currentAvatar'] ?? 'default',
      );
}

/// Achievement data
class Achievement {
  final String id;
  final String title;
  final String description;
  final String icon;
  final DateTime? unlockedAt;
  final bool isSecret;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    this.unlockedAt,
    this.isSecret = false,
  });

  bool get isUnlocked => unlockedAt != null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'icon': icon,
        'unlockedAt': unlockedAt?.toIso8601String(),
        'isSecret': isSecret,
      };

  factory Achievement.fromJson(Map<String, dynamic> json) => Achievement(
        id: json['id'],
        title: json['title'],
        description: json['description'],
        icon: json['icon'],
        unlockedAt: json['unlockedAt'] != null
            ? DateTime.parse(json['unlockedAt'])
            : null,
        isSecret: json['isSecret'] ?? false,
      );
}

/// Sticker reward
class Sticker {
  final String id;
  final String name;
  final String emoji;
  final DateTime earnedAt;

  Sticker({
    required this.id,
    required this.name,
    required this.emoji,
    required this.earnedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'earnedAt': earnedAt.toIso8601String(),
      };

  factory Sticker.fromJson(Map<String, dynamic> json) => Sticker(
        id: json['id'],
        name: json['name'],
        emoji: json['emoji'],
        earnedAt: DateTime.parse(json['earnedAt']),
      );
}

/// Pre-defined achievements
class Achievements {
  static final List<Achievement> all = [
    Achievement(
      id: 'first_session',
      title: 'First Steps',
      description: 'Complete your first practice session',
      icon: '🎉',
    ),
    Achievement(
      id: 'streak_3',
      title: 'Consistent',
      description: 'Practice for 3 days in a row',
      icon: '🔥',
    ),
    Achievement(
      id: 'streak_7',
      title: 'Week Warrior',
      description: 'Practice for 7 days in a row',
      icon: '⭐',
    ),
    Achievement(
      id: 'streak_30',
      title: 'Monthly Master',
      description: 'Practice for 30 days in a row',
      icon: '🏆',
    ),
    Achievement(
      id: 'perfect_score',
      title: 'Perfect!',
      description: 'Get 100% accuracy on an exercise',
      icon: '💯',
    ),
    Achievement(
      id: 'sessions_10',
      title: 'Getting Started',
      description: 'Complete 10 practice sessions',
      icon: '📈',
    ),
    Achievement(
      id: 'sessions_50',
      title: 'Dedicated',
      description: 'Complete 50 practice sessions',
      icon: '💪',
    ),
    Achievement(
      id: 'sessions_100',
      title: 'Speech Champion',
      description: 'Complete 100 practice sessions',
      icon: '👑',
    ),
    Achievement(
      id: 'all_phonemes',
      title: 'Sound Master',
      description: 'Practice all target phonemes',
      icon: '🔤',
    ),
    Achievement(
      id: 'game_master',
      title: 'Game Master',
      description: 'Win all speech games',
      icon: '🎮',
    ),
  ];
}

/// Pre-defined stickers for rewards
class StickerRewards {
  static const List<Map<String, String>> available = [
    {'id': 'star', 'name': 'Gold Star', 'emoji': '⭐'},
    {'id': 'heart', 'name': 'Heart', 'emoji': '❤️'},
    {'id': 'rainbow', 'name': 'Rainbow', 'emoji': '🌈'},
    {'id': 'rocket', 'name': 'Rocket', 'emoji': '🚀'},
    {'id': 'trophy', 'name': 'Trophy', 'emoji': '🏆'},
    {'id': 'unicorn', 'name': 'Unicorn', 'emoji': '🦄'},
    {'id': 'sun', 'name': 'Sunshine', 'emoji': '☀️'},
    {'id': 'butterfly', 'name': 'Butterfly', 'emoji': '🦋'},
    {'id': 'sparkle', 'name': 'Sparkle', 'emoji': '✨'},
    {'id': 'crown', 'name': 'Crown', 'emoji': '👑'},
  ];
}
