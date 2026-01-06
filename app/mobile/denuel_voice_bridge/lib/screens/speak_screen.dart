import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/safe_button.dart';
import '../widgets/mic_button.dart';
import 'after_speaking_screen.dart';

/// SPEAK & BE UNDERSTOOD SCREEN
/// 
/// UX Purpose:
/// - Single, clear action: press the mic button
/// - No pressure, no countdown, no waveforms
/// - "Press when you're ready" - user controls the pace
/// - Large mic button is impossible to miss
/// - Gentle state changes (not jarring)
/// 
/// Accessibility:
/// - Giant touch target for mic button
/// - Clear state indication (ready vs listening)
/// - No time limits
/// - Screen reader announces state changes
class SpeakScreen extends StatefulWidget {
  const SpeakScreen({super.key});

  @override
  State<SpeakScreen> createState() => _SpeakScreenState();
}

class _SpeakScreenState extends State<SpeakScreen> {
  bool _isListening = false;

  void _toggleListening() {
    setState(() {
      _isListening = !_isListening;
    });

    if (!_isListening) {
      // User stopped speaking - navigate to result
      // In real app, this would process the audio first
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => 
                  const AfterSpeakingScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
              transitionDuration: const Duration(milliseconds: 300),
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar with back button
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  SafeIconButton(
                    icon: Icons.arrow_back_rounded,
                    semanticLabel: 'Go back home',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            const Spacer(flex: 1),
            
            // Status message - changes based on state
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Padding(
                key: ValueKey(_isListening),
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    Text(
                      _isListening ? 'I\'m listening…' : 'Press when you\'re ready.',
                      style: AppTextStyles.reassuring,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    if (!_isListening)
                      Text(
                        'Take all the time you need.',
                        style: AppTextStyles.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                  ],
                ),
              ),
            ),
            
            const Spacer(flex: 2),
            
            // Large microphone button - the main action
            MicButton(
              isListening: _isListening,
              onPressed: _toggleListening,
            ),
            
            const Spacer(flex: 2),
            
            // Helpful hint
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _isListening 
                    ? 'Press again when you\'re finished.'
                    : 'Press and speak at your own pace.',
                style: AppTextStyles.bodySmall,
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
