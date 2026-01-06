import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/safe_button.dart';
import '../../widgets/mic_button.dart';
import 'add_voice_sentences_screen.dart';

/// ADD VOICE - STEP 2: WARM-UP
/// 
/// UX Purpose:
/// - Low-pressure first recording
/// - Just to get comfortable
/// - Simple greeting to record
/// - Encouragement after recording
/// 
/// Accessibility:
/// - Large text prompt
/// - Gentle visual feedback
/// - No time pressure
class AddVoiceWarmupScreen extends StatefulWidget {
  const AddVoiceWarmupScreen({super.key});

  @override
  State<AddVoiceWarmupScreen> createState() => _AddVoiceWarmupScreenState();
}

class _AddVoiceWarmupScreenState extends State<AddVoiceWarmupScreen> {
  bool _isRecording = false;
  bool _hasRecorded = false;

  void _toggleRecording() {
    setState(() {
      if (_isRecording) {
        _hasRecorded = true;
      }
      _isRecording = !_isRecording;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _BackButton(onPressed: () => Navigator.pop(context)),
                  const Spacer(),
                  _StepIndicator(currentStep: 2, totalSteps: 5),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const Spacer(),

                    // Title
                    Text(
                      'Let\'s warm up',
                      style: AppTextStyles.headline2,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Say anything that feels natural',
                      style: AppTextStyles.bodyLarge,
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 40),

                    // Prompt card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: _isRecording
                              ? AppColors.listening.withOpacity(0.5)
                              : AppColors.primary.withOpacity(0.1),
                          width: 2,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Try saying:',
                            style: AppTextStyles.label,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '"Hello, my name is..."',
                            style: AppTextStyles.headline2.copyWith(
                              fontStyle: FontStyle.italic,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'or anything you\'d like',
                            style: AppTextStyles.bodySmall,
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // Status message
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        _hasRecorded
                            ? 'Great! That was perfect. ✨'
                            : _isRecording
                                ? 'I\'m listening…'
                                : 'Press when you\'re ready',
                        key: ValueKey('$_isRecording$_hasRecorded'),
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: _hasRecorded 
                              ? AppColors.success 
                              : AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Mic button
                    MicButton(
                      isListening: _isRecording,
                      onPressed: _toggleRecording,
                    ),

                    const Spacer(),

                    // Continue or re-record
                    if (_hasRecorded) ...[
                      SafeButton(
                        icon: Icons.arrow_forward_rounded,
                        label: 'Continue',
                        onPressed: () => _navigateToNext(context),
                        isPrimary: true,
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () {
                          setState(() => _hasRecorded = false);
                        },
                        child: Text(
                          'Record again',
                          style: AppTextStyles.buttonSecondary.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],

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
            const AddVoiceSentencesScreen(),
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

// Reusable widgets (same as previous screens)
class _StepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const _StepIndicator({required this.currentStep, required this.totalSteps});

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

class _BackButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _BackButton({required this.onPressed});

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
          child: Icon(Icons.arrow_back_rounded, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
