import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../theme/child_theme.dart';
import '../../widgets/widgets.dart';
import 'child_practice_screen.dart';
import 'child_games_screen.dart';
import 'child_rewards_screen.dart';
import 'parent_dashboard_screen.dart';
import '../mode_selector/mode_selector_screen.dart';

/// Child Mode Hub - Fun, avatar-led experience
class ChildHubScreen extends StatefulWidget {
  const ChildHubScreen({super.key});

  @override
  State<ChildHubScreen> createState() => _ChildHubScreenState();
}

class _ChildHubScreenState extends State<ChildHubScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: ChildTheme.backgroundGradient,
        ),
        child: IndexedStack(
          index: _currentIndex,
          children: const [
            _ChildHomeTab(),
            ChildPracticeScreen(),
            ChildGamesScreen(),
            ChildRewardsScreen(),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: ChildTheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: ChildTheme.primary.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  emoji: '🏠',
                  isSelected: _currentIndex == 0,
                  onTap: () => setState(() => _currentIndex = 0),
                ),
                _NavItem(
                  icon: Icons.mic_rounded,
                  label: 'Practice',
                  emoji: '🎤',
                  isSelected: _currentIndex == 1,
                  onTap: () => setState(() => _currentIndex = 1),
                ),
                _NavItem(
                  icon: Icons.sports_esports_rounded,
                  label: 'Games',
                  emoji: '🎮',
                  isSelected: _currentIndex == 2,
                  onTap: () => setState(() => _currentIndex = 2),
                ),
                _NavItem(
                  icon: Icons.emoji_events_rounded,
                  label: 'Rewards',
                  emoji: '🏆',
                  isSelected: _currentIndex == 3,
                  onTap: () => setState(() => _currentIndex = 3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String emoji;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.emoji,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: ChildTheme.animationFast,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? ChildTheme.primary.withOpacity(0.15) : null,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              emoji,
              style: TextStyle(fontSize: isSelected ? 28 : 24),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: ChildTheme.bodySmall.copyWith(
                color: isSelected ? ChildTheme.primary : ChildTheme.textTertiary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Home tab with avatar welcome
class _ChildHomeTab extends StatelessWidget {
  const _ChildHomeTab();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsService>();
    final gameProgress = settings.gameProgress;
    final profile = settings.userProfile;
    final userName = profile?.name ?? 'Friend';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Header with settings
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Parent dashboard access
                IconButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ParentDashboardScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.supervisor_account_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: ChildTheme.surface,
                  ),
                ),
                // Mode switch
                IconButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const ModeSelectorScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.swap_horiz_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: ChildTheme.surface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Avatar
            const FriendlyAvatar(
              expression: 'happy',
              size: 140,
              isAnimated: true,
            ),
            const SizedBox(height: 24),

            // Greeting bubble
            SpeechBubble(
              text: _getGreeting(userName),
            ),
            const SizedBox(height: 32),

            // Level & XP
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: ChildTheme.surface,
                borderRadius: BorderRadius.circular(ChildTheme.radiusLarge),
                boxShadow: ChildTheme.cardShadow,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('⭐', style: TextStyle(fontSize: 24)),
                      const SizedBox(width: 8),
                      Text(
                        'Level ${gameProgress.level}',
                        style: ChildTheme.headlineSmall,
                      ),
                      const SizedBox(width: 8),
                      const Text('⭐', style: TextStyle(fontSize: 24)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FunProgressBar(
                    progress: gameProgress.levelProgress,
                    color: ChildTheme.primary,
                    label: 'XP to next level',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Quick stats
            Row(
              children: [
                Expanded(
                  child: _StatBubble(
                    emoji: '🔥',
                    value: '${profile?.currentStreak ?? 0}',
                    label: 'Day Streak',
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatBubble(
                    emoji: '⭐',
                    value: '${gameProgress.stars}',
                    label: 'Stars',
                    color: ChildTheme.star,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Daily challenge
            _DailyChallengeCard(
              onTap: () {
                // Navigate to daily practice
              },
            ),
            const SizedBox(height: 16),

            // Quick practice button
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: ChildTheme.primaryGradient,
                borderRadius: BorderRadius.circular(ChildTheme.radiusLarge),
                boxShadow: [
                  BoxShadow(
                    color: ChildTheme.primary.withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ChildPracticeScreen(),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(ChildTheme.radiusLarge),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🎤', style: TextStyle(fontSize: 32)),
                        const SizedBox(width: 12),
                        Text(
                          "Let's Practice!",
                          style: ChildTheme.buttonText.copyWith(fontSize: 22),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getGreeting(String name) {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning, $name! 🌞\nReady to practice?';
    } else if (hour < 18) {
      return 'Good afternoon, $name! ☀️\nLet\'s have fun together!';
    } else {
      return 'Good evening, $name! 🌙\nTime for some practice!';
    }
  }
}

class _StatBubble extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;
  final Color color;

  const _StatBubble({
    required this.emoji,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ChildTheme.surface,
        borderRadius: BorderRadius.circular(ChildTheme.radiusMedium),
        boxShadow: ChildTheme.cardShadow,
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 8),
          Text(
            value,
            style: ChildTheme.headlineMedium.copyWith(color: color),
          ),
          Text(label, style: ChildTheme.bodySmall),
        ],
      ),
    );
  }
}

class _DailyChallengeCard extends StatelessWidget {
  final VoidCallback onTap;

  const _DailyChallengeCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
        ),
        borderRadius: BorderRadius.circular(ChildTheme.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Text('📅', style: TextStyle(fontSize: 32)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daily Challenge',
                    style: ChildTheme.titleLarge.copyWith(color: Colors.white),
                  ),
                  Text(
                    'Practice for 3 minutes to earn ⭐',
                    style: ChildTheme.bodyMedium.copyWith(
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
