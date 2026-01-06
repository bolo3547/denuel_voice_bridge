import 'package:flutter/material.dart';
import '../../theme/apple_colors.dart';
import '../../theme/apple_text_styles.dart';
import '../../widgets/apple_buttons.dart';
import '../../widgets/apple_list.dart';
import 'apple_home_screen.dart';

/// ADD VOICE - COMPLETE
/// 
/// UX Philosophy:
/// - Celebration without fanfare
/// - Acknowledge the user's effort
/// - Clear next steps
/// - Warm, personal touch
/// 
/// Apple Inspiration:
/// - Apple Pay setup complete
/// - iOS Setup complete screen
/// - Achievement badges
class AppleAddVoiceComplete extends StatefulWidget {
  final String profileName;

  const AppleAddVoiceComplete({
    super.key,
    required this.profileName,
  });

  @override
  State<AppleAddVoiceComplete> createState() => _AppleAddVoiceCompleteState();
}

class _AppleAddVoiceCompleteState extends State<AppleAddVoiceComplete>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticOut,
      ),
    );

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

              // Success icon with animation
              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppleColors.success.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    size: 50,
                    color: AppleColors.success,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Title
              Text(
                'Voice Created',
                style: AppleTextStyles.largeTitle,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              Text(
                '"${widget.profileName}" is ready to use.',
                style: AppleTextStyles.title3.copyWith(
                  color: AppleColors.secondaryLabel,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 48),

              // Profile card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppleColors.secondaryBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    AppleAvatar(
                      initial: widget.profileName[0].toUpperCase(),
                      isActive: true,
                      size: 52,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.profileName,
                            style: AppleTextStyles.headline,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                size: 14,
                                color: AppleColors.success,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Now active',
                                style: AppleTextStyles.footnote.copyWith(
                                  color: AppleColors.success,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 2),

              // What's next
              Text(
                'What would you like to do?',
                style: AppleTextStyles.subheadline,
              ),

              const SizedBox(height: 16),

              ApplePillButton(
                label: 'Try speaking now',
                onPressed: () => _goHome(context, openSpeak: true),
                isPrimary: true,
              ),

              const SizedBox(height: 12),

              ApplePillButton(
                label: 'Go to Home',
                onPressed: () => _goHome(context),
                isPrimary: false,
              ),

              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }

  void _goHome(BuildContext context, {bool openSpeak = false}) {
    Navigator.pushAndRemoveUntil(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const AppleHomeScreen(),
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
      (route) => false,
    );
  }
}
