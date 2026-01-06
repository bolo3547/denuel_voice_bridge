import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/safe_button.dart';
import 'home_screen.dart';
import 'speak_screen.dart';

/// AFTER SPEAKING SCREEN
/// 
/// UX Purpose:
/// - Immediate positive reinforcement: "Thank you. I understood you."
/// - No corrections, no scores, no feedback on "how well" they spoke
/// - Clear options: listen back, try again, or go home
/// - Maintains the calm, safe feeling
/// 
/// Accessibility:
/// - Success state uses same soft colors (no jarring green)
/// - Clear button hierarchy
/// - Screen reader announces success
class AfterSpeakingScreen extends StatelessWidget {
  const AfterSpeakingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            children: [
              const Spacer(flex: 1),
              
              // Success message container
              Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.success.withOpacity(0.15),
                      blurRadius: 32,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Gentle success icon
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_rounded,
                        size: 40,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Main message
                    Text(
                      'Thank you.',
                      style: AppTextStyles.headline2,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'I understood you.',
                      style: AppTextStyles.reassuring.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              const Spacer(flex: 2),
              
              // Action buttons
              SafeButton(
                icon: Icons.volume_up_rounded,
                label: 'Listen to the clear version',
                onPressed: () {
                  // TODO: Play back the processed audio
                  _showListeningDialog(context);
                },
                isPrimary: true,
              ),
              
              const SizedBox(height: 16),
              
              SafeButton(
                icon: Icons.refresh_rounded,
                label: 'Speak again',
                onPressed: () {
                  // Replace current screen with speak screen
                  Navigator.pushReplacement(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) => 
                          const SpeakScreen(),
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 16),
              
              SafeButton(
                icon: Icons.home_rounded,
                label: 'Back home',
                onPressed: () {
                  // Go back to home, clearing the stack
                  Navigator.pushAndRemoveUntil(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) => 
                          const HomeScreen(),
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                    ),
                    (route) => false,
                  );
                },
              ),
              
              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }

  void _showListeningDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: AppColors.surfaceLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Playing indicator
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.volume_up_rounded,
                  size: 32,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Playing your voice…',
                style: AppTextStyles.headline3,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'This is how others will hear you clearly.',
                style: AppTextStyles.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Done',
                  style: AppTextStyles.buttonSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
