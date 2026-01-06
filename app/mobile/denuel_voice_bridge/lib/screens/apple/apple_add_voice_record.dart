import 'package:flutter/material.dart';
import '../../theme/apple_colors.dart';
import '../../theme/apple_text_styles.dart';
import '../../widgets/apple_buttons.dart';
import '../../widgets/apple_mic_button.dart';
import 'apple_add_voice_complete.dart';

/// ADD VOICE - RECORD SAMPLES
/// 
/// UX Philosophy:
/// - One phrase at a time for focus
/// - Clear progress tracking
/// - Patient, encouraging guidance
/// - No pressure to be perfect
/// 
/// Apple Inspiration:
/// - Siri voice training
/// - Voice Memos
/// - iOS Accessibility speech training
class AppleAddVoiceRecord extends StatefulWidget {
  final String profileName;

  const AppleAddVoiceRecord({
    super.key,
    required this.profileName,
  });

  @override
  State<AppleAddVoiceRecord> createState() => _AppleAddVoiceRecordState();
}

class _AppleAddVoiceRecordState extends State<AppleAddVoiceRecord> {
  int _currentPhraseIndex = 0;
  bool _isRecording = false;
  final List<bool> _recorded = [];

  final List<String> _phrases = [
    'Good morning, how are you today?',
    'Thank you very much for your help.',
    'I would like a glass of water, please.',
    'The weather is nice today.',
    'It\'s lovely to see you again.',
    'Could you please repeat that?',
    'I need a moment to think.',
    'Have a wonderful day!',
  ];

  @override
  void initState() {
    super.initState();
    _recorded.addAll(List.filled(_phrases.length, false));
  }

  void _toggleRecording() {
    setState(() {
      if (_isRecording) {
        // Finished recording
        _recorded[_currentPhraseIndex] = true;
        _isRecording = false;

        // Auto-advance after delay
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            if (_currentPhraseIndex < _phrases.length - 1) {
              setState(() {
                _currentPhraseIndex++;
              });
            } else {
              // All done!
              _goToComplete();
            }
          }
        });
      } else {
        _isRecording = true;
      }
    });
  }

  void _goToComplete() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            AppleAddVoiceComplete(profileName: widget.profileName),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final completedCount = _recorded.where((r) => r).length;
    final progress = completedCount / _phrases.length;

    return Scaffold(
      backgroundColor: AppleColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  AppleBackButton(label: 'Back'),
                  const Spacer(),
                  AppleCloseButton(),
                ],
              ),
            ),

            // Progress bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: AppleColors.systemGray4,
                      valueColor: AlwaysStoppedAnimation(AppleColors.accent),
                      minHeight: 4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Step 2 of 3',
                        style: AppleTextStyles.footnote,
                      ),
                      Text(
                        '$completedCount of ${_phrases.length} recorded',
                        style: AppleTextStyles.footnote,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Spacer(flex: 1),

            // Current phrase to read
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  Text(
                    _isRecording ? 'Read this aloud:' : 'Next phrase:',
                    style: AppleTextStyles.subheadline,
                  ),
                  const SizedBox(height: 16),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      '"${_phrases[_currentPhraseIndex]}"',
                      key: ValueKey(_currentPhraseIndex),
                      style: AppleTextStyles.title2.copyWith(
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(flex: 1),

            // Microphone button
            AppleMicButton(
              isListening: _isRecording,
              onPressed: _toggleRecording,
            ),

            const SizedBox(height: 24),

            // Helper text
            Text(
              _isRecording
                  ? 'Tap when finished'
                  : 'Tap to start recording',
              style: AppleTextStyles.footnote,
            ),

            const Spacer(flex: 1),

            // Skip option
            if (!_isRecording && _currentPhraseIndex < _phrases.length - 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: AppleTextButton(
                  label: 'Skip this phrase',
                  onPressed: () {
                    setState(() {
                      if (_currentPhraseIndex < _phrases.length - 1) {
                        _currentPhraseIndex++;
                      }
                    });
                  },
                  color: AppleColors.tertiaryLabel,
                ),
              )
            else
              const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}
