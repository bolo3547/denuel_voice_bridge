import 'package:flutter/material.dart';
import '../../theme/apple_colors.dart';
import '../../theme/apple_text_styles.dart';
import '../../widgets/apple_buttons.dart';
import 'apple_home_screen.dart';
import 'apple_speak_screen.dart';

/// AFTER SPEAKING - Apple Feedback Style
/// 
/// UX Philosophy:
/// - Immediate positive acknowledgment
/// - No analysis, no scores, no judgment
/// - Simple, clear next steps
/// - User remains in control
/// 
/// Apple Inspiration:
/// - Apple Pay success screen
/// - Simple confirmation dialogs
/// - Checkmark with gentle animation
class AppleAfterSpeakingScreen extends StatefulWidget {
  const AppleAfterSpeakingScreen({super.key});

  @override
  State<AppleAfterSpeakingScreen> createState() => _AppleAfterSpeakingScreenState();
}

class _AppleAfterSpeakingScreenState extends State<AppleAfterSpeakingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticOut,
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    // Start animation after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppleColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Success indicator - gentle, not celebratory
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Opacity(
                    opacity: _opacityAnimation.value,
                    child: Transform.scale(
                      scale: _scaleAnimation.value,
                      child: child,
                    ),
                  );
                },
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppleColors.success.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    size: 40,
                    color: AppleColors.success,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Acknowledgment text
              Text(
                'Thank you.',
                style: AppleTextStyles.largeTitle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'I understood you.',
                style: AppleTextStyles.title2.copyWith(
                  color: AppleColors.secondaryLabel,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),

              const Spacer(flex: 2),

              // Action buttons - pill style
              ApplePillButton(
                label: 'Listen to the clear version',
                onPressed: () => _showPlaybackSheet(context),
                isPrimary: true,
              ),

              const SizedBox(height: 12),

              ApplePillButton(
                label: 'Speak again',
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          const AppleSpeakScreen(),
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                    ),
                  );
                },
                isPrimary: false,
              ),

              const SizedBox(height: 24),

              // Text button for back
              AppleTextButton(
                label: 'Back to Home',
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          const AppleHomeScreen(),
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                    ),
                    (route) => false,
                  );
                },
                color: AppleColors.tertiaryLabel,
              ),

              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }

  void _showPlaybackSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppleColors.secondaryBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: AppleColors.systemGray4,
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),

            const SizedBox(height: 24),

            // Playing indicator
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppleColors.accentLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.volume_up_rounded,
                size: 28,
                color: AppleColors.accent,
              ),
            ),

            const SizedBox(height: 20),

            Text(
              'Playing your voice…',
              style: AppleTextStyles.headline,
            ),
            const SizedBox(height: 8),
            Text(
              'This is how others will hear you clearly.',
              style: AppleTextStyles.subheadline,
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 32),

            ApplePillButton(
              label: 'Done',
              onPressed: () => Navigator.pop(context),
              isPrimary: false,
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

/// Reused AnimatedBuilder
class AnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext context, Widget? child) builder;
  final Widget? child;

  const AnimatedBuilder({
    super.key,
    required Animation<double> animation,
    required this.builder,
    this.child,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) => builder(context, child);
}
