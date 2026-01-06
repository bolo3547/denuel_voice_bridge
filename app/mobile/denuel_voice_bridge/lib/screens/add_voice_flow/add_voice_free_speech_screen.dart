import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/safe_button.dart';
import '../../widgets/mic_button.dart';
import 'add_voice_save_screen.dart';

/// ADD VOICE - STEP 4: FREE SPEECH
/// 
/// UX Purpose:
/// - Most natural recording
/// - User speaks freely about anything
/// - Captures natural speech patterns
/// - Encouraging, open-ended prompt
/// 
/// Accessibility:
/// - No specific text to read
/// - Reduces performance anxiety
/// - Gentle suggestions only
class AddVoiceFreeSpeechScreen extends StatefulWidget {
  const AddVoiceFreeSpeechScreen({super.key});

  @override
  State<AddVoiceFreeSpeechScreen> createState() => _AddVoiceFreeSpeechScreenState();
}

class _AddVoiceFreeSpeechScreenState extends State<AddVoiceFreeSpeechScreen> {
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
                  _StepIndicator(currentStep: 4, totalSteps: 5),
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
                      'Now speak freely',
                      style: AppTextStyles.headline2,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Talk about anything you like',
                      style: AppTextStyles.bodyLarge,
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 40),

                    // Suggestions card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.accentLight,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Some ideas:',
                            style: AppTextStyles.label.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _SuggestionItem('Talk about your day'),
                          _SuggestionItem('Describe something you enjoy'),
                          _SuggestionItem('Tell a short story'),
                          _SuggestionItem('Or say whatever comes to mind'),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // Status message
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        _hasRecorded
                            ? 'Wonderful! That was great. ✨'
                            : _isRecording
                                ? 'I\'m listening… take your time'
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
                        label: 'Almost done!',
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
            const AddVoiceSaveScreen(),
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

/// Suggestion item widget
class _SuggestionItem extends StatelessWidget {
  final String text;

  const _SuggestionItem(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            Icons.circle,
            size: 6,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// Reusable widgets
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
