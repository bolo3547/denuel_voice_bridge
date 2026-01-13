import 'package:flutter/material.dart';
import '../../theme/child_theme.dart';
import 'sound_match_game_screen.dart';

/// Speech games screen for Child Mode
class ChildGamesScreen extends StatelessWidget {
  const ChildGamesScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
              Text('Speech Games', style: ChildTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'Have fun while practicing!',
                style: ChildTheme.bodyLarge,
              ),
              const SizedBox(height: 24),

              // Games grid
              _GameCard(
                emoji: '🎯',
                title: 'Sound Match',
                description: 'Match the sounds you hear',
                color: const Color(0xFF6366F1),
                isNew: true,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SoundMatchGameScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _GameCard(
                emoji: '🗣️',
                title: 'Shadow Talk',
                description: 'Speak together with me!',
                color: const Color(0xFFF472B6),
                onTap: () => _showComingSoon(context),
              ),
              const SizedBox(height: 16),
              _GameCard(
                emoji: '🎭',
                title: 'Story Time',
                description: 'Tell a story out loud',
                color: const Color(0xFF10B981),
                onTap: () => _showComingSoon(context),
              ),
              const SizedBox(height: 16),
              _GameCard(
                emoji: '🔤',
                title: 'Sound Safari',
                description: 'Find and say the sounds',
                color: const Color(0xFFF59E0B),
                isLocked: true,
                onTap: () => _showLocked(context),
              ),
              const SizedBox(height: 16),
              _GameCard(
                emoji: '🎵',
                title: 'Rhythm Talk',
                description: 'Speak with the beat',
                color: const Color(0xFF8B5CF6),
                isLocked: true,
                onTap: () => _showLocked(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ChildTheme.radiusLarge),
        ),
        title: Row(
          children: [
            const Text('🚧', style: TextStyle(fontSize: 32)),
            const SizedBox(width: 12),
            Text('Coming Soon!', style: ChildTheme.titleLarge),
          ],
        ),
        content: Text(
          'This game is being built! Check back soon for more fun.',
          style: ChildTheme.bodyLarge,
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK!'),
          ),
        ],
      ),
    );
  }

  void _showLocked(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ChildTheme.radiusLarge),
        ),
        title: Row(
          children: [
            const Text('🔒', style: TextStyle(fontSize: 32)),
            const SizedBox(width: 12),
            Text('Locked!', style: ChildTheme.titleLarge),
          ],
        ),
        content: Text(
          'Keep practicing to unlock this game! You need to reach Level 5.',
          style: ChildTheme.bodyLarge,
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String description;
  final Color color;
  final bool isNew;
  final bool isLocked;
  final VoidCallback onTap;

  const _GameCard({
    required this.emoji,
    required this.title,
    required this.description,
    required this.color,
    this.isNew = false,
    this.isLocked = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isLocked ? 0.6 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: ChildTheme.surface,
          borderRadius: BorderRadius.circular(ChildTheme.radiusLarge),
          boxShadow: ChildTheme.cardShadow,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(ChildTheme.radiusLarge),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        isLocked ? '🔒' : emoji,
                        style: const TextStyle(fontSize: 32),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(title, style: ChildTheme.titleLarge),
                            if (isNew) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: ChildTheme.accent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'NEW',
                                  style: ChildTheme.bodySmall.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(description, style: ChildTheme.bodyMedium),
                      ],
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isLocked ? Icons.lock_rounded : Icons.play_arrow_rounded,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
