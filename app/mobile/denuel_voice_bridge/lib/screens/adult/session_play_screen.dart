import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../theme/adult_theme.dart';
import '../../widgets/widgets.dart';
import 'session_summary_screen.dart';

/// Session play screen for practicing with real-time feedback
class SessionPlayScreen extends StatefulWidget {
  final ScenarioType? scenario;

  const SessionPlayScreen({
    super.key,
    this.scenario,
  });

  @override
  State<SessionPlayScreen> createState() => _SessionPlayScreenState();
}

class _SessionPlayScreenState extends State<SessionPlayScreen> {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  bool _isRecording = false;
  bool _isAnalyzing = false;
  String? _recordingPath;
  Duration _recordingDuration = Duration.zero;
  Timer? _durationTimer;

  int _currentPromptIndex = 0;
  List<String> _prompts = [];
  SpeechMetrics? _currentMetrics;
  List<SpeechMetrics> _sessionMetrics = [];

  late PracticeSession _session;

  @override
  void initState() {
    super.initState();
    _initSession();
    _loadPrompts();
  }

  void _initSession() {
    final sessionService = context.read<SessionService>();
    _session = sessionService.startSession(
      mode: UserMode.adult,
      type: widget.scenario != null ? SessionType.scenario : SessionType.freePractice,
      scenario: widget.scenario,
    );
  }

  void _loadPrompts() {
    if (widget.scenario != null) {
      _prompts = widget.scenario!.samplePrompts;
    } else {
      _prompts = [
        'Practice speaking naturally...',
        'The quick brown fox jumps over the lazy dog.',
        'She sells seashells by the seashore.',
        'How much wood would a woodchuck chuck?',
      ];
    }
  }

  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) return;

    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _recordingPath = '${dir.path}/session_$timestamp.m4a';

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: _recordingPath!,
    );

    setState(() {
      _isRecording = true;
      _recordingDuration = Duration.zero;
    });

    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _recordingDuration += const Duration(seconds: 1));
    });
  }

  Future<void> _stopRecording() async {
    _durationTimer?.cancel();
    final path = await _recorder.stop();

    setState(() {
      _isRecording = false;
      _isAnalyzing = true;
    });

    if (path != null) {
      await _analyzeRecording(path);
    }

    setState(() => _isAnalyzing = false);
  }

  Future<void> _analyzeRecording(String path) async {
    final metricsService = context.read<SpeechMetricsService>();
    final metrics = await metricsService.analyzeAudio(audioPath: path);

    setState(() {
      _currentMetrics = metrics;
      _sessionMetrics.add(metrics);
    });

    // Update session
    final sessionService = context.read<SessionService>();
    sessionService.updateSessionMetrics(metrics);
  }

  void _nextPrompt() {
    if (_currentPromptIndex < _prompts.length - 1) {
      setState(() {
        _currentPromptIndex++;
        _currentMetrics = null;
      });
    }
  }

  void _previousPrompt() {
    if (_currentPromptIndex > 0) {
      setState(() {
        _currentPromptIndex--;
        _currentMetrics = null;
      });
    }
  }

  Future<void> _finishSession() async {
    final sessionService = context.read<SessionService>();
    final settings = context.read<AppSettingsService>();

    // Calculate final metrics
    SpeechMetrics? finalMetrics;
    if (_sessionMetrics.isNotEmpty) {
      final avgClarity = _sessionMetrics.map((m) => m.clarityScore).reduce((a, b) => a + b) / _sessionMetrics.length;
      final avgNasality = _sessionMetrics.map((m) => m.nasalityScore).reduce((a, b) => a + b) / _sessionMetrics.length;
      final avgPacing = _sessionMetrics.map((m) => m.pacingScore).reduce((a, b) => a + b) / _sessionMetrics.length;
      final avgBreath = _sessionMetrics.map((m) => m.breathControlScore).reduce((a, b) => a + b) / _sessionMetrics.length;
      final avgOverall = _sessionMetrics.map((m) => m.overallScore).reduce((a, b) => a + b) / _sessionMetrics.length;

      finalMetrics = SpeechMetrics(
        clarityScore: avgClarity,
        nasalityScore: avgNasality,
        pacingScore: avgPacing,
        breathControlScore: avgBreath,
        overallScore: avgOverall,
        phonemeErrors: _sessionMetrics.expand((m) => m.phonemeErrors).toList(),
        suggestions: _sessionMetrics.expand((m) => m.suggestions).toSet().toList(),
        timestamp: DateTime.now(),
      );
    }

    final completedSession = await sessionService.endSession(
      finalMetrics: finalMetrics,
      audioPath: _recordingPath,
    );

    if (completedSession != null) {
      await settings.recordSession(completedSession.duration);
    }

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => SessionSummaryScreen(session: completedSession!),
        ),
      );
    }
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdultTheme.background,
      appBar: AppBar(
        backgroundColor: AdultTheme.background,
        title: Text(widget.scenario?.displayName ?? 'Free Practice'),
        actions: [
          TextButton(
            onPressed: _sessionMetrics.isNotEmpty ? _finishSession : null,
            child: const Text('Finish'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Prompt card
              if (_prompts.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AdultTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AdultTheme.border),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Prompt ${_currentPromptIndex + 1}/${_prompts.length}',
                            style: AdultTheme.labelMedium,
                          ),
                          Row(
                            children: [
                              IconButton(
                                onPressed: _currentPromptIndex > 0 ? _previousPrompt : null,
                                icon: const Icon(Icons.chevron_left),
                                iconSize: 20,
                              ),
                              IconButton(
                                onPressed: _currentPromptIndex < _prompts.length - 1 ? _nextPrompt : null,
                                icon: const Icon(Icons.chevron_right),
                                iconSize: 20,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _prompts[_currentPromptIndex],
                        style: AdultTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Metrics display
              if (_currentMetrics != null) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    MetricChip(
                      label: 'Clarity',
                      value: _currentMetrics!.clarityScore,
                    ),
                    MetricChip(
                      label: 'Pacing',
                      value: _currentMetrics!.pacingScore * 20, // Scale for display
                    ),
                    MetricChip(
                      label: 'Breath',
                      value: _currentMetrics!.breathControlScore,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Suggestions
                if (_currentMetrics!.suggestions.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AdultTheme.info.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AdultTheme.info.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.lightbulb_outline, 
                                color: AdultTheme.info, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Suggestions',
                              style: AdultTheme.labelLarge.copyWith(
                                color: AdultTheme.info,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...(_currentMetrics!.suggestions.take(2).map((s) => 
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('• $s', style: AdultTheme.bodyMedium),
                          ),
                        )),
                      ],
                    ),
                  ),
              ],

              const Spacer(),

              // Waveform
              WaveformWidget(
                isActive: _isRecording,
                color: _isRecording ? AdultTheme.error : AdultTheme.primary,
                height: 60,
              ),
              const SizedBox(height: 24),

              // Recording indicator
              RecordingIndicator(
                duration: _recordingDuration,
                isRecording: _isRecording,
              ),
              const SizedBox(height: 24),

              // Mic button
              if (_isAnalyzing)
                Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text('Analyzing...', style: AdultTheme.bodyMedium),
                  ],
                )
              else
                AdultMicButton(
                  isRecording: _isRecording,
                  onTap: _isRecording ? _stopRecording : _startRecording,
                  size: 80,
                ),

              const SizedBox(height: 16),
              Text(
                _isRecording ? 'Tap to stop' : 'Tap to start recording',
                style: AdultTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
