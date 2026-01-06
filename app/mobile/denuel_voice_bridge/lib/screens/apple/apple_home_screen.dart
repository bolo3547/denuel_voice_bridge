import 'package:flutter/material.dart';
import '../../theme/apple_colors.dart';
import '../../theme/apple_text_styles.dart';
import '../../widgets/apple_buttons.dart';
import 'apple_speak_screen.dart';
import 'apple_practice_screen.dart';
import 'apple_profiles_screen.dart';

/// HOME SCREEN - Apple Calm Welcome
/// 
/// UX Philosophy:
/// - First impression must be CALM and SAFE
/// - Minimal visual elements
/// - Typography carries the message
/// - White space creates breathing room
/// - No icons competing for attention
/// 
/// Apple Inspiration:
/// - Apple Health app's welcoming screens
/// - macOS System Preferences simplicity
/// - iOS Accessibility features calm approach
class AppleHomeScreen extends StatelessWidget {
  const AppleHomeScreen({super.key});

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
              const SizedBox(height: 60),

              // App name - subtle, not prominent
              Text(
                'Denuel Voice Bridge',
                style: AppleTextStyles.footnote.copyWith(
                  color: AppleColors.tertiaryLabel,
                  letterSpacing: 1,
                ),
              ),

              const SizedBox(height: 40),

              // Main reassurance - the emotional anchor
              // Large, clear, calming
              Text(
                'You are safe here.',
                style: AppleTextStyles.largeTitle,
              ),
              const SizedBox(height: 8),
              Text(
                'Take your time.',
                style: AppleTextStyles.title2.copyWith(
                  color: AppleColors.secondaryLabel,
                  fontWeight: FontWeight.w400,
                ),
              ),

              const Spacer(),

              // Action cards - clean, minimal, inviting
              AppleCardButton(
                title: 'Speak & Be Understood',
                subtitle: 'I\'ll help clarify your voice',
                onPressed: () => _navigate(context, const AppleSpeakScreen()),
                showChevron: true,
              ),

              const SizedBox(height: 12),

              AppleCardButton(
                title: 'Practice with Notes',
                subtitle: 'Read along at your own pace',
                onPressed: () => _navigate(context, const ApplePracticeScreen()),
                showChevron: true,
              ),

              const SizedBox(height: 12),

              AppleCardButton(
                title: 'My Voice Profiles',
                subtitle: 'Manage your saved voices',
                onPressed: () => _navigate(context, const AppleProfilesScreen()),
                showChevron: true,
              ),

              const Spacer(),

              // Privacy footer - always visible, builds trust
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 32),
                  child: Text(
                    'Your voice stays on this device.',
                    style: AppleTextStyles.footnote,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigate(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Apple-style slide from right
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
