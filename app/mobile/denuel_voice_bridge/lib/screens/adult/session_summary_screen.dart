import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;

// Web-only helpers
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/services.dart';
import '../../theme/adult_theme.dart';
import '../../widgets/widgets.dart';

/// Session summary screen showing results after practice
class SessionSummaryScreen extends StatefulWidget {
  final PracticeSession session;

  const SessionSummaryScreen({
    super.key,
    required this.session,
  });

  @override
  State<SessionSummaryScreen> createState() => _SessionSummaryScreenState();
}

class _SessionSummaryScreenState extends State<SessionSummaryScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  html.AudioElement? _webAudio;

  @override
  void initState() {
    super.initState();
    _setupAudioPlayer();
  }

  void _setupAudioPlayer() {
    if (!kIsWeb) {
      _audioPlayer.onDurationChanged.listen((d) {
        if (mounted) setState(() => _duration = d);
      });
      _audioPlayer.onPositionChanged.listen((p) {
        if (mounted) setState(() => _position = p);
      });
      _audioPlayer.onPlayerComplete.listen((_) {
        if (mounted) setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      });
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _webAudio?.pause();
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    if (widget.session.processedAudioBase64 == null) return;

    if (kIsWeb) {
      if (_isPlaying) {
        _webAudio?.pause();
        setState(() => _isPlaying = false);
      } else {
        final audioBytes = base64Decode(widget.session.processedAudioBase64!);
        final blob = html.Blob([audioBytes], 'audio/${widget.session.processedAudioFormat ?? 'wav'}');
        final url = html.Url.createObjectUrlFromBlob(blob);
        _webAudio = html.AudioElement(url);
        _webAudio!.onEnded.listen((_) {
          if (mounted) setState(() => _isPlaying = false);
        });
        _webAudio!.play();
        setState(() => _isPlaying = true);
      }
    } else {
      if (_isPlaying) {
        await _audioPlayer.pause();
        setState(() => _isPlaying = false);
      } else {
        final audioBytes = base64Decode(widget.session.processedAudioBase64!);
        final dir = await getTemporaryDirectory();
        final file = io.File('${dir.path}/playback_temp.${widget.session.processedAudioFormat ?? 'wav'}');
        await file.writeAsBytes(audioBytes);
        await _audioPlayer.play(DeviceFileSource(file.path));
        setState(() => _isPlaying = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
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

              const SizedBox(height: 24),

              // Notes section
              _buildNotesSection(context, session),

              const SizedBox(height: 32),

              // Playback section (if processed audio available)
              if (session.processedAudioBase64 != null) ...[
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
                          Icon(Icons.headphones_rounded, color: AdultTheme.primary),
                          const SizedBox(width: 8),
                          Text('Processed Audio', style: AdultTheme.titleMedium),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                              color: AdultTheme.primary,
                              size: 48,
                            ),
                            onPressed: _togglePlayback,
                          ),
                          const SizedBox(width: 12),
                          if (!kIsWeb) ...[
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SliderTheme(
                                    data: SliderThemeData(
                                      trackHeight: 4,
                                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                    ),
                                    child: Slider(
                                      value: _duration.inMilliseconds > 0
                                          ? _position.inMilliseconds / _duration.inMilliseconds
                                          : 0,
                                      onChanged: (v) async {
                                        final pos = Duration(milliseconds: (v * _duration.inMilliseconds).toInt());
                                        await _audioPlayer.seek(pos);
                                      },
                                      activeColor: AdultTheme.primary,
                                      inactiveColor: AdultTheme.border,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(_formatTime(_position), style: AdultTheme.labelSmall),
                                        Text(_formatTime(_duration), style: AdultTheme.labelSmall),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            Expanded(
                              child: Text(
                                _isPlaying ? 'Playing...' : 'Tap to play processed audio',
                                style: AdultTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

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

              const SizedBox(height: 12),

              // Export / Share
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.file_download_outlined),
                      label: const Text('Export Session'),
                      onPressed: () => _exportSession(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.share_rounded),
                      label: const Text('Share'),
                      onPressed: () => _shareSession(context),
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

  Future<void> _exportSession(BuildContext context) async {
    final session = widget.session;
    final jsonStr = const JsonEncoder.withIndent('  ').convert(session.toJson());
    final filenameJson = 'session_${session.id}.json';

    try {
      if (kIsWeb) {
        // Download JSON
        final bytes = utf8.encode(jsonStr);
        final blob = html.Blob([bytes], 'application/json');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', filenameJson)
          ..click();
        html.Url.revokeObjectUrl(url);

        // If processed audio exists, download it too
        if (session.processedAudioBase64 != null) {
          final audioBytes = base64Decode(session.processedAudioBase64!);
          final audioBlob = html.Blob([audioBytes], 'audio/${session.processedAudioFormat ?? 'wav'}');
          final audioUrl = html.Url.createObjectUrlFromBlob(audioBlob);
          final audioName = 'session_${session.id}.${session.processedAudioFormat ?? 'wav'}';
          final anchor2 = html.AnchorElement(href: audioUrl)
            ..setAttribute('download', audioName)
            ..click();
          html.Url.revokeObjectUrl(audioUrl);
        }

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Export started (web)')));
      } else {
        final dir = await getTemporaryDirectory();
        final file = io.File('${dir.path}/$filenameJson');
        await file.writeAsString(jsonStr);

        final filesToShare = <String>[file.path];

        if (session.processedAudioBase64 != null) {
          final audioBytes = base64Decode(session.processedAudioBase64!);
          final audioName = 'session_${session.id}.${session.processedAudioFormat ?? 'wav'}';
          final audioFile = io.File('${dir.path}/$audioName');
          await audioFile.writeAsBytes(audioBytes);
          filesToShare.add(audioFile.path);
        }

        await Share.shareXFiles(filesToShare.map((p) => XFile(p)).toList(), text: 'Session export');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Export prepared for sharing')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _shareSession(BuildContext context) async {
    final session = widget.session;
    try {
      if (session.processedAudioBase64 != null) {
        if (kIsWeb) {
          // Save JSON and audio and then open share dialog isn't standard on web; offer download instead
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('On web, use Export to download files.')));
          return;
        }

        final dir = await getTemporaryDirectory();
        final audioBytes = base64Decode(session.processedAudioBase64!);
        final audioName = 'session_${session.id}.${session.processedAudioFormat ?? 'wav'}';
        final audioFile = io.File('${dir.path}/$audioName');
        await audioFile.writeAsBytes(audioBytes);

        await Share.shareXFiles([XFile(audioFile.path)], text: 'Processed audio from session');
      } else {
        final jsonStr = const JsonEncoder.withIndent('  ').convert(session.toJson());
        if (kIsWeb) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('On web, use Export to download files.')));
          return;
        }

        final dir = await getTemporaryDirectory();
        final filenameJson = 'session_${session.id}.json';
        final file = io.File('${dir.path}/$filenameJson');
        await file.writeAsString(jsonStr);
        await Share.shareXFiles([XFile(file.path)], text: 'Session export');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Share failed: $e')));
    }
  }

  Widget _buildNotesSection(BuildContext context, PracticeSession session) {
    return Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.note_alt_outlined, color: AdultTheme.textTertiary),
                  const SizedBox(width: 8),
                  Text('Session Notes', style: AdultTheme.titleMedium),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                color: AdultTheme.primary,
                onPressed: () => _showAddNoteDialog(context, session),
                tooltip: 'Add note',
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (session.notes.isEmpty)
            Text(
              'No notes yet. Tap + to add one.',
              style: AdultTheme.bodySmall,
            )
          else
            ...session.notes.asMap().entries.map((entry) {
              final index = entry.key;
              final note = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(fontSize: 16)),
                    Expanded(
                      child: Text(note, style: AdultTheme.bodyMedium),
                    ),
                    InkWell(
                      onTap: () => _deleteNote(context, session, index),
                      child: Icon(
                        Icons.close,
                        size: 18,
                        color: AdultTheme.textTertiary,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  void _showAddNoteDialog(BuildContext context, PracticeSession session) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Note'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter your note...',
          ),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                context.read<SessionService>().addNoteToSession(
                  session.id,
                  controller.text,
                );
              }
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _deleteNote(BuildContext context, PracticeSession session, int index) {
    final updatedNotes = List<String>.from(session.notes)..removeAt(index);
    context.read<SessionService>().updateSessionNotes(session.id, updatedNotes);
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

  String _formatTime(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
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
