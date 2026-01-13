import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../theme/child_theme.dart';
import '../../widgets/widgets.dart';

/// Rewards and achievements screen for Child Mode
class ChildRewardsScreen extends StatelessWidget {
  const ChildRewardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsService>();
    final gameProgress = settings.gameProgress;

    return Container(
      decoration: const BoxDecoration(
        gradient: ChildTheme.backgroundGradient,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with stars
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('My Rewards', style: ChildTheme.headlineMedium),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: ChildTheme.star.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Text('⭐', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 8),
                        Text(
                          '${gameProgress.stars}',
                          style: ChildTheme.titleLarge.copyWith(
                            color: ChildTheme.gold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Level progress
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: ChildTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(ChildTheme.radiusLarge),
                  boxShadow: [
                    BoxShadow(
                      color: ChildTheme.primary.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text('🏆', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 12),
                    Text(
                      'Level ${gameProgress.level}',
                      style: ChildTheme.headlineLarge.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: gameProgress.levelProgress,
                        backgroundColor: Colors.white.withOpacity(0.3),
                        valueColor: const AlwaysStoppedAnimation(Colors.white),
                        minHeight: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${gameProgress.experience}/${gameProgress.experienceToNextLevel} XP',
                      style: ChildTheme.bodyMedium.copyWith(
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Stickers collection
              Text('My Stickers', style: ChildTheme.titleLarge),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: ChildTheme.surface,
                  borderRadius: BorderRadius.circular(ChildTheme.radiusLarge),
                  boxShadow: ChildTheme.cardShadow,
                ),
                child: gameProgress.stickers.isEmpty
                    ? Column(
                        children: [
                          const Text('📭', style: TextStyle(fontSize: 48)),
                          const SizedBox(height: 12),
                          Text(
                            'No stickers yet!',
                            style: ChildTheme.titleMedium,
                          ),
                          Text(
                            'Keep practicing to earn stickers',
                            style: ChildTheme.bodyMedium,
                          ),
                        ],
                      )
                    : Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: gameProgress.stickers.map((sticker) {
                          return Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: ChildTheme.surfaceVariant,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                sticker.emoji,
                                style: const TextStyle(fontSize: 32),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
              ),
              const SizedBox(height: 32),

              // Achievements
              Text('Achievements', style: ChildTheme.titleLarge),
              const SizedBox(height: 16),
              ...Achievements.all.map((achievement) {
                final isUnlocked = gameProgress.achievements
                    .any((a) => a.id == achievement.id);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _AchievementCard(
                    achievement: achievement,
                    isUnlocked: isUnlocked,
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  final Achievement achievement;
  final bool isUnlocked;

  const _AchievementCard({
    required this.achievement,
    required this.isUnlocked,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isUnlocked ? 1.0 : 0.5,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ChildTheme.surface,
          borderRadius: BorderRadius.circular(ChildTheme.radiusMedium),
          boxShadow: isUnlocked ? ChildTheme.cardShadow : null,
          border: isUnlocked
              ? Border.all(color: ChildTheme.star, width: 2)
              : Border.all(color: ChildTheme.border),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isUnlocked
                    ? ChildTheme.star.withOpacity(0.2)
                    : ChildTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  isUnlocked ? achievement.icon : '🔒',
                  style: const TextStyle(fontSize: 28),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    achievement.title,
                    style: ChildTheme.titleMedium,
                  ),
                  Text(
                    achievement.description,
                    style: ChildTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (isUnlocked)
              const Icon(
                Icons.check_circle_rounded,
                color: ChildTheme.success,
                size: 28,
              ),
          ],
        ),
      ),
    );
  }
}
