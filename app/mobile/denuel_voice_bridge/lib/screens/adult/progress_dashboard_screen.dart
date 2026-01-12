import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../theme/adult_theme.dart';

/// Progress dashboard showing analytics and trends
class ProgressDashboardScreen extends StatelessWidget {
  const ProgressDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sessions = context.watch<SessionService>();
    final settings = context.watch<AppSettingsService>();
    final profile = settings.userProfile;

    final weekSessions = sessions.weekSessions;
    final avgScore = sessions.getAverageScore(weekSessions);
    final totalTime = sessions.getTotalPracticeTime(weekSessions);

    return Scaffold(
      backgroundColor: AdultTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your Progress', style: AdultTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'Track your speech improvement over time',
                style: AdultTheme.bodyLarge,
              ),
              const SizedBox(height: 24),

              // Weekly stats
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AdultTheme.primary, AdultTheme.primaryDark],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This Week',
                      style: AdultTheme.titleMedium.copyWith(
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _WeekStatItem(
                            value: '${weekSessions.length}',
                            label: 'Sessions',
                          ),
                        ),
                        Expanded(
                          child: _WeekStatItem(
                            value: '${totalTime.inMinutes}',
                            label: 'Minutes',
                          ),
                        ),
                        Expanded(
                          child: _WeekStatItem(
                            value: avgScore > 0 ? '${avgScore.toInt()}%' : '--',
                            label: 'Avg Score',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Streak info
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AdultTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AdultTheme.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.local_fire_department_rounded,
                        color: Colors.orange,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${profile?.currentStreak ?? 0} Day Streak',
                            style: AdultTheme.titleLarge,
                          ),
                          Text(
                            'Best: ${profile?.longestStreak ?? 0} days',
                            style: AdultTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.emoji_events_rounded,
                      color: Colors.amber,
                      size: 32,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Score trend chart
              Text('Score Trend', style: AdultTheme.titleLarge),
              const SizedBox(height: 16),
              Container(
                height: 200,
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AdultTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AdultTheme.border),
                ),
                child: sessions.completedSessions.length >= 2
                    ? _ScoreChart(sessions: sessions.completedSessions.take(10).toList())
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.show_chart_rounded,
                              size: 48,
                              color: AdultTheme.textTertiary,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Complete more sessions\nto see your trend',
                              style: AdultTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 24),

              // All-time stats
              Text('All Time', style: AdultTheme.titleLarge),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.check_circle_outline,
                      value: '${profile?.totalSessions ?? 0}',
                      label: 'Sessions',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.access_time,
                      value: '${profile?.totalMinutes ?? 0}',
                      label: 'Minutes',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Recent sessions
              if (sessions.recentSessions.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Recent Sessions', style: AdultTheme.titleLarge),
                    TextButton(
                      onPressed: () {},
                      child: const Text('Export'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...sessions.recentSessions.take(5).map((session) {
                  return _SessionListItem(session: session);
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _WeekStatItem extends StatelessWidget {
  final String value;
  final String label;

  const _WeekStatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: AdultTheme.headlineMedium.copyWith(color: Colors.white),
        ),
        Text(
          label,
          style: AdultTheme.bodySmall.copyWith(
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AdultTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdultTheme.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: AdultTheme.primary, size: 32),
          const SizedBox(height: 12),
          Text(value, style: AdultTheme.headlineSmall),
          Text(label, style: AdultTheme.bodySmall),
        ],
      ),
    );
  }
}

class _ScoreChart extends StatelessWidget {
  final List<PracticeSession> sessions;

  const _ScoreChart({required this.sessions});

  @override
  Widget build(BuildContext context) {
    final reversedSessions = sessions.reversed.toList();
    final spots = reversedSessions.asMap().entries.map((e) {
      final score = e.value.finalMetrics?.overallScore ?? 0;
      return FlSpot(e.key.toDouble(), score);
    }).toList();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 25,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: AdultTheme.border,
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 25,
              reservedSize: 35,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt()}',
                  style: AdultTheme.bodySmall,
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (sessions.length - 1).toDouble(),
        minY: 0,
        maxY: 100,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AdultTheme.primary,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: AdultTheme.primary,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: AdultTheme.primary.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionListItem extends StatelessWidget {
  final PracticeSession session;

  const _SessionListItem({required this.session});

  @override
  Widget build(BuildContext context) {
    final score = session.finalMetrics?.overallScore ?? 0;

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
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AdultTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                session.scenario?.icon ?? session.type.icon,
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),
          const SizedBox(width: 12),
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${score.toInt()}%',
                style: AdultTheme.titleMedium.copyWith(
                  color: _getScoreColor(score),
                ),
              ),
              Text(
                _formatDuration(session.duration),
                style: AdultTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 80) return AdultTheme.success;
    if (score >= 60) return AdultTheme.warning;
    return AdultTheme.error;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    return '${date.day}/${date.month}';
  }

  String _formatDuration(Duration d) {
    if (d.inMinutes < 1) return '${d.inSeconds}s';
    return '${d.inMinutes}m';
  }
}
