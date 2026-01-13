import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../theme/adult_theme.dart';
import 'scenario_selection_screen.dart';
import 'breath_exercise_screen.dart';
import 'progress_dashboard_screen.dart';
import 'adult_settings_screen.dart';
import 'phoneme_practice_screen.dart';
import 'daily_tips_screen.dart';
import '../mode_selector/mode_selector_screen.dart';

/// Adult Mode Hub - Professional dashboard
class AdultHubScreen extends StatefulWidget {
  const AdultHubScreen({super.key});

  @override
  State<AdultHubScreen> createState() => _AdultHubScreenState();
}

class _AdultHubScreenState extends State<AdultHubScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdultTheme.background,
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          _AdultHomeTab(),
          ScenarioSelectionScreen(),
          ProgressDashboardScreen(),
          AdultSettingsScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AdultTheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  isSelected: _currentIndex == 0,
                  onTap: () => setState(() => _currentIndex = 0),
                ),
                _NavItem(
                  icon: Icons.mic_rounded,
                  label: 'Practice',
                  isSelected: _currentIndex == 1,
                  onTap: () => setState(() => _currentIndex = 1),
                ),
                _NavItem(
                  icon: Icons.insights_rounded,
                  label: 'Progress',
                  isSelected: _currentIndex == 2,
                  onTap: () => setState(() => _currentIndex = 2),
                ),
                _NavItem(
                  icon: Icons.settings_rounded,
                  label: 'Settings',
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
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AdultTheme.primary.withOpacity(0.1) : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AdultTheme.primary : AdultTheme.textTertiary,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: AdultTheme.labelMedium.copyWith(
                color: isSelected ? AdultTheme.primary : AdultTheme.textTertiary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Home tab content
class _AdultHomeTab extends StatelessWidget {
  const _AdultHomeTab();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsService>();
    final sessions = context.watch<SessionService>();
    final userName = settings.userProfile?.name ?? 'there';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back,',
                      style: AdultTheme.bodyLarge,
                    ),
                    Text(
                      userName,
                      style: AdultTheme.headlineMedium,
                    ),
                  ],
                ),
                // Mode switch button
                IconButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const ModeSelectorScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.swap_horiz_rounded),
                  tooltip: 'Switch Mode',
                  style: IconButton.styleFrom(
                    backgroundColor: AdultTheme.surfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Stats cards
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.local_fire_department_rounded,
                    iconColor: Colors.orange,
                    value: '${settings.userProfile?.currentStreak ?? 0}',
                    label: 'Day Streak',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.timer_rounded,
                    iconColor: AdultTheme.primary,
                    value: '${settings.userProfile?.totalMinutes ?? 0}',
                    label: 'Minutes',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.check_circle_rounded,
                    iconColor: AdultTheme.success,
                    value: '${settings.userProfile?.totalSessions ?? 0}',
                    label: 'Sessions',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Quick actions
            Text('Quick Start', style: AdultTheme.titleLarge),
            const SizedBox(height: 16),
            _QuickActionCard(
              icon: Icons.air_rounded,
              title: 'Breath Exercise',
              subtitle: 'Calm your mind before practice',
              color: AdultTheme.info,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const BreathExerciseScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _QuickActionCard(
              icon: Icons.work_rounded,
              title: 'Job Interview Practice',
              subtitle: 'Common interview scenarios',
              color: AdultTheme.primary,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ScenarioSelectionScreen(
                      preselectedScenario: ScenarioType.jobInterview,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _QuickActionCard(
              icon: Icons.phone_in_talk_rounded,
              title: 'Phone Call Practice',
              subtitle: 'Improve clarity for calls',
              color: AdultTheme.success,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ScenarioSelectionScreen(
                      preselectedScenario: ScenarioType.phoneCall,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _QuickActionCard(
              icon: Icons.record_voice_over_rounded,
              title: 'Phoneme Practice',
              subtitle: 'Target specific sounds (P, B, K, G...)',
              color: const Color(0xFF8B5CF6),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PhonemePracticeScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _QuickActionCard(
              icon: Icons.lightbulb_rounded,
              title: 'Tips & Techniques',
              subtitle: 'Daily speech improvement tips',
              color: const Color(0xFFF59E0B),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const DailyTipsScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),

            // Recent sessions
            if (sessions.recentSessions.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Recent Sessions', style: AdultTheme.titleLarge),
                  TextButton(
                    onPressed: () {
                      // Navigate to progress
                    },
                    child: const Text('See All'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...sessions.recentSessions.take(3).map((session) {
                return _RecentSessionCard(session: session);
              }),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdultTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdultTheme.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: AdultTheme.headlineSmall,
          ),
          Text(
            label,
            style: AdultTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AdultTheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AdultTheme.border),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AdultTheme.titleMedium),
                    Text(subtitle, style: AdultTheme.bodySmall),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AdultTheme.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentSessionCard extends StatelessWidget {
  final PracticeSession session;

  const _RecentSessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final score = session.finalMetrics?.overallScore ?? 0;
    final scoreColor = score >= 80
        ? AdultTheme.success
        : score >= 60
            ? AdultTheme.warning
            : AdultTheme.error;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdultTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdultTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: scoreColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '${score.toInt()}',
                style: AdultTheme.titleMedium.copyWith(color: scoreColor),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.scenario?.displayName ?? session.type.displayName,
                  style: AdultTheme.titleMedium,
                ),
                Text(
                  _formatDate(session.startTime),
                  style: AdultTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            _formatDuration(session.duration),
            style: AdultTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays} days ago';
  }

  String _formatDuration(Duration d) {
    if (d.inMinutes < 1) return '${d.inSeconds}s';
    return '${d.inMinutes}m';
  }
}
