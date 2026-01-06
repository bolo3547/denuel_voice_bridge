import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/safe_button.dart';
import 'add_voice_warmup_screen.dart';

/// ADD VOICE - STEP 1: INTRODUCTION & REASSURANCE
/// 
/// UX Purpose:
/// - Explain what will happen (no surprises)
/// - Reassure user about privacy
/// - Set expectations (no pressure)
/// - User can leave at any time
/// 
/// Accessibility:
/// - Clear, simple language
/// - Step indicator shows progress
/// - Large "Continue" button
class AddVoiceIntroScreen extends StatelessWidget {
  const AddVoiceIntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar with close button
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _CloseButton(onPressed: () => Navigator.pop(context)),
                  const Spacer(),
                  // Step indicator
                  _StepIndicator(currentStep: 1, totalSteps: 5),
                  const Spacer(),
                  const SizedBox(width: 48), // Balance
                ],
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const Spacer(),

                    // Welcoming icon
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.record_voice_over_rounded,
                        size: 40,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Main message
                    Text(
                      'Let\'s create your voice profile',
                      style: AppTextStyles.headline2,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'This helps the app understand your unique voice. '
                      'There\'s no right or wrong way to do this.',
                      style: AppTextStyles.bodyLarge,
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 48),

                    // What to expect
                    _InfoCard(
                      icon: Icons.timer_outlined,
                      title: 'Takes about 3 minutes',
                      subtitle: 'You can pause or stop anytime',
                    ),
                    const SizedBox(height: 12),
                    _InfoCard(
                      icon: Icons.lock_outline_rounded,
                      title: 'Stays on your device',
                      subtitle: 'Your voice is never uploaded',
                    ),
                    const SizedBox(height: 12),
                    _InfoCard(
                      icon: Icons.favorite_outline_rounded,
                      title: 'No pressure',
                      subtitle: 'Speak at your own pace',
                    ),

                    const Spacer(flex: 2),

                    // Continue button
                    SafeButton(
                      icon: Icons.arrow_forward_rounded,
                      label: 'I\'m ready to begin',
                      onPressed: () => _navigateToNext(context),
                      isPrimary: true,
                    ),

                    const SizedBox(height: 16),

                    // Cancel option - always visible
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Maybe later',
                        style: AppTextStyles.buttonSecondary.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToNext(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => 
            const AddVoiceWarmupScreen(),
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
      ),
    );
  }
}

/// Info card for explaining the process
class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                )),
                Text(subtitle, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Step indicator widget
class _StepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const _StepIndicator({
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(totalSteps, (index) {
        final isCompleted = index < currentStep - 1;
        final isCurrent = index == currentStep - 1;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isCurrent ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isCompleted || isCurrent
                ? AppColors.primary
                : AppColors.primary.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

/// Close button widget
class _CloseButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _CloseButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceLight,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          child: Icon(
            Icons.close_rounded,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
