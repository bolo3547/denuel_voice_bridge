import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// SafeButton - A calm, accessible button widget
/// 
/// UX Purpose:
/// - Large touch targets (minimum 64px height)
/// - Rounded corners feel friendly
/// - No harsh edges or aggressive styling
/// - Clear visual hierarchy (primary vs secondary)
/// 
/// Accessibility:
/// - Semantic label for screen readers
/// - High contrast
/// - Visible focus states
/// - Adequate spacing for motor impairments
class SafeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;
  final bool isLoading;

  const SafeButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isPrimary = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: isPrimary ? AppColors.primary : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        elevation: 0,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(20),
          splashColor: isPrimary 
              ? AppColors.primaryLight.withOpacity(0.3)
              : AppColors.primary.withOpacity(0.1),
          highlightColor: isPrimary
              ? AppColors.primaryLight.withOpacity(0.2)
              : AppColors.primary.withOpacity(0.05),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: isPrimary 
                  ? null 
                  : Border.all(
                      color: AppColors.primary.withOpacity(0.2),
                      width: 1.5,
                    ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation(
                        isPrimary ? AppColors.textOnPrimary : AppColors.primary,
                      ),
                    ),
                  )
                else
                  Icon(
                    icon,
                    size: 28,
                    color: isPrimary ? AppColors.textOnPrimary : AppColors.primary,
                  ),
                const SizedBox(width: 16),
                Flexible(
                  child: Text(
                    label,
                    style: isPrimary 
                        ? AppTextStyles.button 
                        : AppTextStyles.buttonSecondary,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// SafeIconButton - A circular icon button for single actions
/// Used for back buttons, close buttons, etc.
class SafeIconButton extends StatelessWidget {
  final IconData icon;
  final String semanticLabel;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Color? iconColor;

  const SafeIconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.backgroundColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: backgroundColor ?? AppColors.surfaceLight,
        shape: const CircleBorder(),
        elevation: 0,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          splashColor: AppColors.primary.withOpacity(0.1),
          child: Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 24,
              color: iconColor ?? AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
