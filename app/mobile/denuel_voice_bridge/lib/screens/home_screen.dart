import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/safe_button.dart';
import 'speak_screen.dart';
import 'practice_screen.dart';
import 'voice_profiles_screen.dart';

/// HOME SCREEN
/// 
/// UX Purpose:
/// - First thing the user sees - must feel immediately safe
/// - "You are safe here" message provides emotional grounding
/// - Three clear options, no overwhelm
/// - Large buttons reduce motor skill pressure
/// 
/// Accessibility:
/// - Semantic labels on all buttons
/// - High contrast text
/// - Minimum touch target 64px
/// - Screen reader friendly structure
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
              
              // App title - subtle, not overwhelming
              Text(
                'Denuel Voice Bridge',
                style: AppTextStyles.headline3.copyWith(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 48),
              
              // Main reassurance message
              // This is the emotional anchor of the app
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Gentle icon
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.favorite_rounded,
                        size: 32,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'You are safe here.',
                      style: AppTextStyles.reassuring,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Take your time.',
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              const Spacer(flex: 2),
              
              // Main action buttons - generous spacing
              SafeButton(
                icon: Icons.mic_rounded,
                label: 'Speak & Be Understood',
                onPressed: () => _navigateTo(context, const SpeakScreen()),
                isPrimary: true,
              ),
              
              const SizedBox(height: 16),
              
              SafeButton(
                icon: Icons.article_rounded,
                label: 'Practice with Notes',
                onPressed: () => _navigateTo(context, const PracticeScreen()),
              ),
              
              const SizedBox(height: 16),
              
              SafeButton(
                icon: Icons.person_rounded,
                label: 'My Voice Profiles',
                onPressed: () => _navigateTo(context, const VoiceProfilesScreen()),
              ),
              
              const Spacer(flex: 1),
              
              // Privacy reassurance - always visible
              Text(
                'Your voice stays on this device only.',
                style: AppTextStyles.privacy,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Gentle fade transition - not jarring
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }
}
