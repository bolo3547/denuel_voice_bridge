import 'package:flutter/material.dart';
import '../../theme/apple_colors.dart';
import '../../theme/apple_text_styles.dart';
import '../../widgets/apple_buttons.dart';
import '../../widgets/apple_mic_button.dart';
import 'apple_after_speaking_screen.dart';

/// SPEAK & BE UNDERSTOOD - Apple Voice Memos Style
/// 
/// UX Philosophy:
/// - Single focus: the microphone button
/// - Maximum white space for calm
/// - Text guides without pressure
/// - No waveforms, no timers, no anxiety triggers
/// - Gentle state transitions
/// 
/// Apple Inspiration:
/// - Voice Memos recording interface
/// - Siri listening state
/// - Minimal, purposeful animation
class AppleSpeakScreen extends StatefulWidget {
  const AppleSpeakScreen({super.key});

  @override
  State<AppleSpeakScreen> createState() => _AppleSpeakScreenState();
}

class _AppleSpeakScreenState extends State<AppleSpeakScreen> {
  bool _isListening = false;

  void _toggleListening() {
    setState(() {
      _isListening = !_isListening;
    });

    if (!_isListening) {
      // Finished speaking - gentle transition
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  const AppleAfterSpeakingScreen(),
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
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppleColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar - minimal
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  AppleBackButton(label: 'Back'),
                  const Spacer(),
                ],
              ),
            ),

            const Spacer(flex: 2),

            // Status text - calm, guiding
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Column(
                key: ValueKey(_isListening),
                children: [
                  Text(
                    _isListening ? 'I\'m listening…' : 'Press when you\'re ready.',
                    style: AppleTextStyles.title2,
                    textAlign: TextAlign.center,
                  ),
                  if (!_isListening) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Take all the time you need.',
                      style: AppleTextStyles.subheadline,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),

            const Spacer(flex: 2),

            // Microphone button - the star of the show
            AppleMicButton(
              isListening: _isListening,
              onPressed: _toggleListening,
            ),

            const Spacer(flex: 2),

            // Helper text
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Text(
                _isListening
                    ? 'Tap the button when you\'re finished.'
                    : 'Speak naturally. There\'s no rush.',
                style: AppleTextStyles.footnote,
                textAlign: TextAlign.center,
              ),
            ),

            const Spacer(flex: 1),
          ],
        ),
      ),
    );
  }
}
