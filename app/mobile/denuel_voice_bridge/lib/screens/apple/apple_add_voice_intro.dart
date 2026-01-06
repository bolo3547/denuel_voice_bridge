import 'package:flutter/material.dart';
import '../../theme/apple_colors.dart';
import '../../theme/apple_text_styles.dart';
import '../../widgets/apple_buttons.dart';
import 'apple_add_voice_name.dart';

/// ADD VOICE - INTRODUCTION
/// 
/// UX Philosophy:
/// - Explain what will happen in simple terms
/// - Set expectations clearly
/// - No technical jargon
/// - Reassure about privacy
/// 
/// Apple Inspiration:
/// - iOS Setup assistant pages
/// - Privacy explanation screens
/// - Face ID setup flow
class AppleAddVoiceIntro extends StatelessWidget {
  const AppleAddVoiceIntro({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppleColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    const Spacer(),
                    AppleCloseButton(),
                  ],
                ),
              ),

              const Spacer(flex: 1),

              // Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppleColors.accentLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.record_voice_over_rounded,
                  size: 36,
                  color: AppleColors.accent,
                ),
              ),

              const SizedBox(height: 32),

              // Title
              Text(
                'Let\'s create\nyour voice.',
                style: AppleTextStyles.largeTitle,
              ),

              const SizedBox(height: 16),

              // Explanation
              Text(
                'I\'ll ask you to record a few short phrases. '
                'These recordings help me learn your unique voice, '
                'so I can make it clearer for others to understand.',
                style: AppleTextStyles.body.copyWith(
                  color: AppleColors.secondaryLabel,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 24),

              // What to expect
              _ExpectationRow(
                icon: Icons.mic_outlined,
                text: '5-10 short recordings',
              ),
              const SizedBox(height: 12),
              _ExpectationRow(
                icon: Icons.timer_outlined,
                text: 'About 3-5 minutes',
              ),
              const SizedBox(height: 12),
              _ExpectationRow(
                icon: Icons.lock_outline_rounded,
                text: 'Stays on this device',
              ),

              const Spacer(flex: 2),

              // Continue button
              ApplePillButton(
                label: 'Continue',
                onPressed: () => _goToNameScreen(context),
                isPrimary: true,
              ),

              const SizedBox(height: 16),

              Center(
                child: Text(
                  'You can stop at any time.',
                  style: AppleTextStyles.footnote,
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  void _goToNameScreen(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const AppleAddVoiceName(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }
}

class _ExpectationRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ExpectationRow({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 22,
          color: AppleColors.secondaryLabel,
        ),
        const SizedBox(width: 12),
        Text(
          text,
          style: AppleTextStyles.body.copyWith(
            color: AppleColors.secondaryLabel,
          ),
        ),
      ],
    );
  }
}
