import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:confetti/confetti.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../theme/child_theme.dart';
import '../../widgets/widgets.dart';

/// Child-friendly speech practice screen
class ChildPracticeScreen extends StatefulWidget {
  const ChildPracticeScreen({super.key});

  @override
  State<ChildPracticeScreen> createState() => _ChildPracticeScreenState();
}

class _ChildPracticeScreenState extends State<ChildPracticeScreen>
    with TickerProviderStateMixin {
  final AudioRecorder _recorder = AudioRecorder();
  late ConfettiController _confettiController;

  bool _isRecording = false;
  bool _isAnalyzing = false;
  bool _showResult = false;
  String? _recordingPath;
  Duration _recordingDuration = Duration.zero;
  Timer? _durationTimer;

  int _currentPromptIndex = 0;
  SpeechMetrics? _currentMetrics;
  int _earnedStars = 0;

  String _avatarExpression = 'happy';
  String _avatarMessage = 'Tap the microphone and say the words!';

  final List<Map<String, String>> _prompts = [
    {'text': 'Hello, how are you?', 'emoji': '👋'},
    {'text': 'My name is...', 'emoji': '😊'},
    {'text': 'The sun is shining', 'emoji': '☀️'},
    {'text': 'I like to play', 'emoji': '🎮'},
    {'text': 'Thank you very much', 'emoji': '🙏'},
    {'text': 'See you later!', 'emoji': '👋'},
  ];

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _recorder.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) return;

    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _recordingPath = '${dir.path}/child_practice_$timestamp.m4a';

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: _recordingPath!,
    );

    setState(() {
      _isRecording = true;
      _recordingDuration = Duration.zero;
      _avatarExpression = 'listening';
      _avatarMessage = "I'm listening... Keep going! 👂";
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
      _avatarExpression = 'thinking';
      _avatarMessage = 'Let me see how you did... 🤔';
    });

    if (path != null) {
      await _analyzeRecording(path);
    }
  }

  Future<void> _analyzeRecording(String path) async {
    final metricsService = context.read<SpeechMetricsService>();
    final metrics = await metricsService.analyzeAudio(audioPath: path);

    // Calculate stars based on score
    final score = metrics.overallScore;
    int stars = 0;
    if (score >= 90) {
      stars = 3;
    } else if (score >= 70) {
      stars = 2;
    } else if (score >= 50) {
      stars = 1;
    }

    setState(() {
      _currentMetrics = metrics;
      _earnedStars = stars;
      _isAnalyzing = false;
      _showResult = true;
      _avatarExpression = stars >= 2 ? 'celebrating' : 'encouraging';
      _avatarMessage = _getResultMessage(stars);
    });

    if (stars >= 2) {
      _confettiController.play();
    }

    // Update game progress
    final settings = context.read<AppSettingsService>();
    await settings.addStars(stars);
    await settings.addExperience(10 + (stars * 10));
  }

  String _getResultMessage(int stars) {
    switch (stars) {
      case 3:
        return 'AMAZING! Perfect score! 🌟🌟🌟';
      case 2:
        return 'Great job! Keep it up! 🌟🌟';
      case 1:
        return "Good try! Let's practice more! 🌟";
      default:
        return "Nice effort! Let's try again! 💪";
    }
  }

  void _nextPrompt() {
    setState(() {
      _currentPromptIndex = (_currentPromptIndex + 1) % _prompts.length;
      _showResult = false;
      _currentMetrics = null;
      _earnedStars = 0;
      _avatarExpression = 'happy';
      _avatarMessage = 'Tap the microphone and say the words!';
    });
  }

  void _tryAgain() {
    setState(() {
      _showResult = false;
      _currentMetrics = null;
      _earnedStars = 0;
      _avatarExpression = 'encouraging';
      _avatarMessage = "Let's try again! You can do it! 💪";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main content
        Container(
          decoration: const BoxDecoration(
            gradient: ChildTheme.backgroundGradient,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Progress dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_prompts.length, (index) {
                      return Container(
                        width: index == _currentPromptIndex ? 24 : 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: index <= _currentPromptIndex
                              ? ChildTheme.primary
                              : ChildTheme.border,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),

                  // Avatar
                  FriendlyAvatar(
                    expression: _avatarExpression,
                    size: 120,
                    isAnimated: true,
                    isSpeaking: false,
                  ),
                  const SizedBox(height: 16),

                  // Avatar message
                  SpeechBubble(text: _avatarMessage),
                  const SizedBox(height: 32),

                  // Prompt card
                  if (!_showResult) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: ChildTheme.surface,
                        borderRadius: BorderRadius.circular(ChildTheme.radiusLarge),
                        boxShadow: ChildTheme.cardShadow,
                      ),
                      child: Column(
                        children: [
                          Text(
                            _prompts[_currentPromptIndex]['emoji']!,
                            style: const TextStyle(fontSize: 48),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _prompts[_currentPromptIndex]['text']!,
                            style: ChildTheme.headlineMedium,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Result card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: ChildTheme.surface,
                        borderRadius: BorderRadius.circular(ChildTheme.radiusLarge),
                        boxShadow: ChildTheme.cardShadow,
                      ),
                      child: Column(
                        children: [
                          StarRating(
                            stars: _earnedStars,
                            size: 48,
                            animated: true,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Score: ${_currentMetrics?.overallScore.toInt() ?? 0}%',
                            style: ChildTheme.headlineMedium.copyWith(
                              color: ChildTheme.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '+${10 + (_earnedStars * 10)} XP',
                            style: ChildTheme.titleMedium.copyWith(
                              color: ChildTheme.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const Spacer(),

                  // Recording duration
                  if (_isRecording)
                    Text(
                      '${_recordingDuration.inSeconds}s',
                      style: ChildTheme.headlineLarge.copyWith(
                        color: ChildTheme.accent,
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Mic button or action buttons
                  if (!_showResult) ...[
                    if (_isAnalyzing)
                      Column(
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text('Checking...', style: ChildTheme.bodyLarge),
                        ],
                      )
                    else
                      ChildMicButton(
                        isRecording: _isRecording,
                        onTap: _isRecording ? _stopRecording : _startRecording,
                        size: 100,
                      ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _tryAgain,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text('Try Again'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _nextPrompt,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text('Next'),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 16),
                  if (!_showResult && !_isRecording && !_isAnalyzing)
                    Text(
                      'Tap to start!',
                      style: ChildTheme.bodyMedium,
                    ),
                ],
              ),
            ),
          ),
        ),

        // Confetti
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [
              ChildTheme.primary,
              ChildTheme.accent,
              ChildTheme.success,
              ChildTheme.star,
            ],
          ),
        ),
      ],
    );
  }
}
