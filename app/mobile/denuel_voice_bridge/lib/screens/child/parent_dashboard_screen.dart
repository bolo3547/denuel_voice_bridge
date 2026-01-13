import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/services.dart';
import '../../models/models.dart';
import '../../theme/adult_theme.dart';

/// Parent/Therapist dashboard for monitoring child's progress
class ParentDashboardScreen extends StatefulWidget {
  const ParentDashboardScreen({super.key});

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen> {
  bool _isAuthenticated = false;
  final _pinController = TextEditingController();

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _authenticate() {
    // Simple PIN check (in production, use proper auth)
    if (_pinController.text == '1234') {
      setState(() => _isAuthenticated = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incorrect PIN')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAuthenticated) {
      return _buildPinScreen();
    }
    return _buildDashboard();
  }

  Widget _buildPinScreen() {
    return Scaffold(
      backgroundColor: AdultTheme.background,
      appBar: AppBar(
        title: const Text('Parent Access'),
        backgroundColor: AdultTheme.background,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.lock_rounded,
                size: 64,
                color: AdultTheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Enter Parent PIN',
                style: AdultTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'This area is for parents and therapists',
                style: AdultTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                textAlign: TextAlign.center,
                style: AdultTheme.headlineMedium,
                decoration: InputDecoration(
                  hintText: '• • • •',
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _authenticate,
                  child: const Text('Enter'),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Default PIN: 1234',
                style: AdultTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    final settings = context.watch<AppSettingsService>();
    final sessions = context.watch<SessionService>();
    final profile = settings.userProfile;
    final gameProgress = settings.gameProgress;

    return Scaffold(
      backgroundColor: AdultTheme.background,
      appBar: AppBar(
        title: const Text('Parent Dashboard'),
        backgroundColor: AdultTheme.background,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => setState(() => _isAuthenticated = false),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Child info
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
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AdultTheme.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text('👦', style: TextStyle(fontSize: 32)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile?.name ?? 'Child',
                            style: AdultTheme.titleLarge,
                          ),
                          Text(
                            'Level ${gameProgress.level}',
                            style: AdultTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Stats overview
              Text('Progress Overview', style: AdultTheme.titleLarge),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      title: 'Total Sessions',
                      value: '${profile?.totalSessions ?? 0}',
                      icon: Icons.mic_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      title: 'Practice Time',
                      value: '${profile?.totalMinutes ?? 0} min',
                      icon: Icons.timer_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      title: 'Current Streak',
                      value: '${profile?.currentStreak ?? 0} days',
                      icon: Icons.local_fire_department_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      title: 'Stars Earned',
                      value: '${gameProgress.stars}',
                      icon: Icons.star_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Recent activity
              Text('Recent Sessions', style: AdultTheme.titleLarge),
              const SizedBox(height: 16),
              if (sessions.recentSessions.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AdultTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AdultTheme.border),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.history_rounded,
                        size: 48,
                        color: AdultTheme.textTertiary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No sessions yet',
                        style: AdultTheme.bodyMedium,
                      ),
                    ],
                  ),
                )
              else
                ...sessions.recentSessions.take(5).map((session) {
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
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AdultTheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              session.type.icon,
                              style: const TextStyle(fontSize: 24),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                session.type.displayName,
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
                }),
              const SizedBox(height: 24),

              // Therapist notes section
              Text('Therapist Notes', style: AdultTheme.titleLarge),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AdultTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AdultTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.note_alt_outlined, 
                            color: AdultTheme.textTertiary),
                        const SizedBox(width: 8),
                        Text('Auto-generated insights', 
                            style: AdultTheme.labelMedium),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _generateInsights(profile, gameProgress),
                      style: AdultTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => _exportChildReport(context),
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('Export Report'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _generateInsights(dynamic profile, dynamic gameProgress) {
    final sessions = profile?.totalSessions ?? 0;
    final streak = profile?.currentStreak ?? 0;
    final level = gameProgress?.level ?? 1;

    if (sessions == 0) {
      return 'No practice sessions completed yet. Encourage your child to start their first session!';
    }

    String insight = '';
    if (streak >= 7) {
      insight += 'Excellent consistency! ${profile?.name ?? "Child"} has maintained a $streak-day streak. ';
    } else if (streak >= 3) {
      insight += 'Good progress on building a daily habit with a $streak-day streak. ';
    } else {
      insight += 'Encourage daily practice to build consistency. ';
    }

    insight += 'Currently at Level $level with $sessions total sessions completed.';

    return insight;
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
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDuration(Duration d) {
    if (d.inMinutes < 1) return '${d.inSeconds}s';
    return '${d.inMinutes}m';
  }

  Future<void> _exportChildReport(BuildContext context) async {
    final sessionService = context.read<SessionService>();
    final settings = context.read<AppSettingsService>();
    final sessions = sessionService.allSessions;
    final profile = settings.userProfile;

    // Build comprehensive child progress report
    final reportData = {
      'reportType': 'Child Progress Report',
      'exportDate': DateTime.now().toIso8601String(),
      'childProfile': {
        'name': profile?.name ?? 'Child',
        'totalSessions': profile?.totalSessions ?? 0,
        'currentStreak': profile?.currentStreak ?? 0,
        'longestStreak': profile?.longestStreak ?? 0,
        'totalPracticeMinutes': profile?.totalMinutes ?? 0,
      },
      'sessionHistory': sessions.map((s) {
        return {
          'id': s.id,
          'mode': s.mode.name,
          'type': s.type.name,
          'scenario': s.scenario?.name,
          'startTime': s.startTime.toIso8601String(),
          'endTime': s.endTime?.toIso8601String(),
          'duration': s.duration.inSeconds,
          'transcript': s.transcript,
          'notes': s.notes,
          'overallScore': s.finalMetrics?.overallScore,
        };
      }).toList(),
      'insights': _generateInsights(profile, null),
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(reportData);
    final fileName = 'child_progress_report_${DateTime.now().millisecondsSinceEpoch}.json';

    if (kIsWeb) {
      // Web: trigger download
      final bytes = utf8.encode(jsonString);
      final blob = html.Blob([bytes], 'application/json');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      html.Url.revokeObjectUrl(url);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report downloaded!')),
      );
    } else {
      // Native: share file
      try {
        final tempDir = await getTemporaryDirectory();
        final file = io.File('${tempDir.path}/$fileName');
        await file.writeAsString(jsonString);

        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Child Progress Report - Denuel Voice Bridge',
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdultTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdultTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AdultTheme.primary, size: 24),
          const SizedBox(height: 12),
          Text(value, style: AdultTheme.headlineSmall),
          Text(title, style: AdultTheme.bodySmall),
        ],
      ),
    );
  }
}
