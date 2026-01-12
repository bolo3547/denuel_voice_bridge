import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../theme/adult_theme.dart';
import '../../widgets/widgets.dart';

/// Session summary screen showing results after practice
class SessionSummaryScreen extends StatelessWidget {
  final PracticeSession session;

  const SessionSummaryScreen({
    super.key,
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    final metrics = session.finalMetrics;
    final score = metrics?.overallScore ?? 0;

    return Scaffold(
      backgroundColor: AdultTheme.background,
      appBar: AppBar(
        backgroundColor: AdultTheme.background,
        title: const Text('Session Complete'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Score circle
              Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _getScoreColor(score),
                      _getScoreColor(score).withOpacity(0.7),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _getScoreColor(score).withOpacity(0.3),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${score.toInt()}',
                      style: AdultTheme.metricValue.copyWith(
                        color: Colors.white,
                        fontSize: 48,
                      ),
                    ),
                    Text(
                      'Overall Score',
                      style: AdultTheme.labelMedium.copyWith(
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Session info
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AdultTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AdultTheme.border),
                ),
                child: Column(
                  children: [
                    _InfoRow(
                      icon: Icons.timer_outlined,
                      label: 'Duration',
                      value: _formatDuration(session.duration),
                    ),
                    const Divider(height: 24),
                    _InfoRow(
                      icon: Icons.category_outlined,
                      label: 'Type',
                      value: session.scenario?.displayName ?? 
                             session.type.displayName,
                    ),
                    const Divider(height: 24),
                    _InfoRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Date',
                      value: _formatDate(session.startTime),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Metrics breakdown
              if (metrics != null) ...[
                Text('Detailed Metrics', style: AdultTheme.titleLarge),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: MetricCard(
                        label: 'Clarity',
                        value: metrics.clarityScore,
                        unit: '%',
                        icon: Icons.record_voice_over_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: MetricCard(
                        label: 'Breath',
                        value: metrics.breathControlScore,
                        unit: '%',
                        icon: Icons.air_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: MetricCard(
                        label: 'Pacing',
                        value: metrics.pacingScore,
                        unit: 'syl/s',
                        showProgress: false,
                        icon: Icons.speed_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: MetricCard(
                        label: 'Nasality',
                        value: metrics.nasalityScore,
                        unit: '%',
                        icon: Icons.tune_outlined,
                        severity: metrics.nasalityScore < 40 
                            ? MetricSeverity.good 
                            : metrics.nasalityScore < 60 
                                ? MetricSeverity.moderate 
                                : MetricSeverity.needsWork,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Suggestions
                if (metrics.suggestions.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AdultTheme.info.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AdultTheme.info.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.tips_and_updates_outlined, 
                                color: AdultTheme.info),
                            const SizedBox(width: 8),
                            Text(
                              'Recommendations',
                              style: AdultTheme.titleMedium.copyWith(
                                color: AdultTheme.info,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...metrics.suggestions.map((s) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('• ', style: TextStyle(fontSize: 16)),
                              Expanded(
                                child: Text(s, style: AdultTheme.bodyMedium),
                              ),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ),
                ],
              ],

              const SizedBox(height: 32),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).pop();
                      },
                      child: const Text('Back to Home'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text('Practice Again'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 80) return AdultTheme.success;
    if (score >= 60) return AdultTheme.warning;
    return AdultTheme.error;
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    if (minutes > 0) {
      return '$minutes min $seconds sec';
    }
    return '$seconds seconds';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AdultTheme.textTertiary, size: 20),
        const SizedBox(width: 12),
        Text(label, style: AdultTheme.bodyMedium),
        const Spacer(),
        Text(value, style: AdultTheme.titleMedium),
      ],
    );
  }
}
