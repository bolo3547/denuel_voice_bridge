import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/safe_button.dart';
import '../home_screen.dart';

/// ADD VOICE - STEP 5: SAVE PROFILE
/// 
/// UX Purpose:
/// - Final step - name the profile
/// - Celebration of completion
/// - Reassurance about privacy
/// - Clear next step
/// 
/// Accessibility:
/// - Simple text input
/// - Large save button
/// - Positive completion message
class AddVoiceSaveScreen extends StatefulWidget {
  const AddVoiceSaveScreen({super.key});

  @override
  State<AddVoiceSaveScreen> createState() => _AddVoiceSaveScreenState();
}

class _AddVoiceSaveScreenState extends State<AddVoiceSaveScreen> {
  final TextEditingController _nameController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = 'My Voice';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty) return;

    setState(() => _isSaving = true);

    // Simulate saving (in real app, this would save to local storage)
    await Future.delayed(const Duration(seconds: 1));

    if (mounted) {
      _showSuccessAndNavigateHome();
    }
  }

  void _showSuccessAndNavigateHome() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: AppColors.surfaceLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success icon
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
              const SizedBox(height: 24),

              Text(
                'Voice profile saved!',
                style: AppTextStyles.headline2,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'You did wonderfully. Your voice profile "${_nameController.text}" is ready to use.',
                style: AppTextStyles.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              SafeButton(
                icon: Icons.home_rounded,
                label: 'Go to Home',
                onPressed: () {
                  // Clear navigation stack and go home
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
                isPrimary: true,
              ),
            ],
          ),
        ),
      ),
    );
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
                  _StepIndicator(currentStep: 5, totalSteps: 5),
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

                    // Celebration icon
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.celebration_rounded,
                        size: 40,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Title
                    Text(
                      'All done!',
                      style: AppTextStyles.headline2,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Give your voice profile a name',
                      style: AppTextStyles.bodyLarge,
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 40),

                    // Name input
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.2),
                          width: 2,
                        ),
                      ),
                      child: TextField(
                        controller: _nameController,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.headline3,
                        decoration: InputDecoration(
                          hintText: 'Enter a name',
                          hintStyle: AppTextStyles.headline3.copyWith(
                            color: AppColors.textMuted,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(24),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Privacy notice
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.accentLight,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Stored on this device only',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(flex: 2),

                    // Save button
                    SafeButton(
                      icon: Icons.save_rounded,
                      label: 'Save Voice Profile',
                      onPressed: _saveProfile,
                      isPrimary: true,
                      isLoading: _isSaving,
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
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
