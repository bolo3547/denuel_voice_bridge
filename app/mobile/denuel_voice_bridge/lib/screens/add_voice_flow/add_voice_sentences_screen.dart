import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/safe_button.dart';
import '../../widgets/mic_button.dart';
import 'add_voice_free_speech_screen.dart';

/// ADD VOICE - STEP 3: SENTENCES
/// 
/// UX Purpose:
/// - Record a few natural sentences
/// - Variety helps the voice profile
/// - No pressure to be "correct"
/// - Progress visible but not stressful
/// 
/// Accessibility:
/// - Large, readable sentence prompts
/// - Clear progress indicator
/// - Gentle transitions between sentences
class AddVoiceSentencesScreen extends StatefulWidget {
  const AddVoiceSentencesScreen({super.key});

  @override
  State<AddVoiceSentencesScreen> createState() => _AddVoiceSentencesScreenState();
}

class _AddVoiceSentencesScreenState extends State<AddVoiceSentencesScreen> {
  bool _isRecording = false;
  int _currentSentence = 0;
  final List<bool> _recorded = [false, false, false, false];

  final List<String> _sentences = [
    'The weather today is beautiful.',
    'I would like a cup of tea, please.',
    'Thank you for your patience.',
    'It was nice talking to you.',
  ];

  void _toggleRecording() {
    setState(() {
      if (_isRecording) {
        _recorded[_currentSentence] = true;
        // Move to next sentence after a brief pause
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted && _currentSentence < _sentences.length - 1) {
            setState(() => _currentSentence++);
          }
        });
      }
      _isRecording = !_isRecording;
    });
  }

  bool get _allRecorded => _recorded.every((r) => r);

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
                  _StepIndicator(currentStep: 3, totalSteps: 5),
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
                    const SizedBox(height: 16),

                    // Title
                    Text(
                      'Read these sentences',
                      style: AppTextStyles.headline2,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Say them however feels natural',
                      style: AppTextStyles.bodyLarge,
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 24),

                    // Sentence progress
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_sentences.length, (index) {
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: _recorded[index]
                                ? AppColors.success
                                : index == _currentSentence
                                    ? AppColors.primary
                                    : AppColors.primary.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: _recorded[index]
                                ? Icon(Icons.check_rounded, 
                                    size: 18, color: Colors.white)
                                : Text(
                                    '${index + 1}',
                                    style: AppTextStyles.label.copyWith(
                                      color: index == _currentSentence
                                          ? Colors.white
                                          : AppColors.textMuted,
                                      fontSize: 14,
                                    ),
                                  ),
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: 32),

                    // Current sentence card
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: _isRecording
                                ? AppColors.listening.withOpacity(0.5)
                                : _recorded[_currentSentence]
                                    ? AppColors.success.withOpacity(0.3)
                                    : AppColors.primary.withOpacity(0.1),
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Text(
                              _sentences[_currentSentence],
                              key: ValueKey(_currentSentence),
                              style: AppTextStyles.headline2.copyWith(
                                fontSize: 24,
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Status
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        _recorded[_currentSentence]
                            ? '✓ Recorded'
                            : _isRecording
                                ? 'I\'m listening…'
                                : 'Press to record',
                        key: ValueKey('${_isRecording}_${_recorded[_currentSentence]}'),
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: _recorded[_currentSentence]
                              ? AppColors.success
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Mic button
                    MicButton(
                      isListening: _isRecording,
                      onPressed: _toggleRecording,
                    ),

                    const SizedBox(height: 24),

                    // Navigation
                    if (_allRecorded)
                      SafeButton(
                        icon: Icons.arrow_forward_rounded,
                        label: 'Continue',
                        onPressed: () => _navigateToNext(context),
                        isPrimary: true,
                      )
                    else
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_currentSentence > 0)
                            TextButton.icon(
                              onPressed: () {
                                setState(() => _currentSentence--);
                              },
                              icon: Icon(Icons.chevron_left_rounded,
                                  color: AppColors.textMuted),
                              label: Text('Previous',
                                  style: AppTextStyles.buttonSecondary
                                      .copyWith(color: AppColors.textMuted)),
                            ),
                          if (_currentSentence > 0 && 
                              _currentSentence < _sentences.length - 1)
                            const SizedBox(width: 16),
                          if (_currentSentence < _sentences.length - 1 &&
                              _recorded[_currentSentence])
                            TextButton.icon(
                              onPressed: () {
                                setState(() => _currentSentence++);
                              },
                              icon: Icon(Icons.chevron_right_rounded,
                                  color: AppColors.primary),
                              label: Text('Next',
                                  style: AppTextStyles.buttonSecondary),
                            ),
                        ],
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
            const AddVoiceFreeSpeechScreen(),
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
