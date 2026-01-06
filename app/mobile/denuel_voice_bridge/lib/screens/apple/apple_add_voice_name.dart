import 'package:flutter/material.dart';
import '../../theme/apple_colors.dart';
import '../../theme/apple_text_styles.dart';
import '../../widgets/apple_buttons.dart';
import 'apple_add_voice_record.dart';

/// ADD VOICE - NAME YOUR PROFILE
/// 
/// UX Philosophy:
/// - Personal naming creates ownership
/// - Simple, single-purpose screen
/// - Keyboard-friendly
/// - No validation stress
/// 
/// Apple Inspiration:
/// - iOS Add Contact name field
/// - HomeKit device naming
/// - Siri Shortcut naming
class AppleAddVoiceName extends StatefulWidget {
  const AppleAddVoiceName({super.key});

  @override
  State<AppleAddVoiceName> createState() => _AppleAddVoiceNameState();
}

class _AppleAddVoiceNameState extends State<AppleAddVoiceName> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Auto-focus after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool get _canContinue => _controller.text.trim().isNotEmpty;

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
                    AppleBackButton(label: 'Back'),
                    const Spacer(),
                    AppleCloseButton(),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Progress indicator - subtle
              _ProgressDots(currentStep: 1, totalSteps: 3),

              const SizedBox(height: 40),

              // Title
              Text(
                'What should I call\nthis voice?',
                style: AppleTextStyles.largeTitle,
              ),

              const SizedBox(height: 12),

              Text(
                'Choose a name that\'s meaningful to you.',
                style: AppleTextStyles.subheadline,
              ),

              const SizedBox(height: 40),

              // Text input - Apple style
              Container(
                decoration: BoxDecoration(
                  color: AppleColors.secondaryBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  style: AppleTextStyles.body,
                  decoration: InputDecoration(
                    hintText: 'e.g., "My Voice" or "Dad\'s Voice"',
                    hintStyle: AppleTextStyles.body.copyWith(
                      color: AppleColors.tertiaryLabel,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                  onChanged: (_) => setState(() {}),
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) {
                    if (_canContinue) _goToRecord();
                  },
                ),
              ),

              const Spacer(),

              // Continue button
              ApplePillButton(
                label: 'Continue',
                onPressed: _canContinue ? _goToRecord : null,
                isPrimary: true,
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  void _goToRecord() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            AppleAddVoiceRecord(profileName: _controller.text.trim()),
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

class _ProgressDots extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const _ProgressDots({
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: List.generate(totalSteps, (index) {
        final isActive = index < currentStep;
        return Container(
          margin: const EdgeInsets.only(right: 8),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? AppleColors.accent : AppleColors.systemGray4,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
