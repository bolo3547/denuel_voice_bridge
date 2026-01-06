import 'package:flutter/material.dart';
import '../theme/apple_colors.dart';
import '../theme/apple_text_styles.dart';

/// Apple-style pill button (primary action)
/// 
/// UX Philosophy:
/// - Large touch target (50px minimum height)
/// - Rounded corners like iOS buttons
/// - Subtle press state, no harsh feedback
/// - Text-focused, icons optional
class ApplePillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final bool isLoading;
  final IconData? icon;

  const ApplePillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isPrimary = true,
    this.isLoading = false,
    this.icon,
  });

  bool get _isDisabled => onPressed == null || isLoading;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Opacity(
        opacity: _isDisabled ? 0.5 : 1.0,
        child: Material(
          color: isPrimary ? AppleColors.accent : AppleColors.secondaryBackground,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: _isDisabled ? null : onPressed,
            borderRadius: BorderRadius.circular(12),
            splashColor: isPrimary 
                ? Colors.white.withOpacity(0.1)
                : AppleColors.accent.withOpacity(0.05),
            highlightColor: isPrimary
                ? Colors.white.withOpacity(0.05)
                : AppleColors.accent.withOpacity(0.02),
          child: Container(
            width: double.infinity,
            height: 50,
            alignment: Alignment.center,
            child: isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(
                        isPrimary ? Colors.white : AppleColors.accent,
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(
                          icon,
                          size: 20,
                          color: isPrimary ? Colors.white : AppleColors.accent,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        label,
                        style: isPrimary 
                            ? AppleTextStyles.button
                            : AppleTextStyles.buttonSecondary,
                      ),
                    ],
                  ),
          ),
        ),
        ),
      ),
    );
  }
}

/// Apple-style card button (for home screen options)
/// 
/// UX Philosophy:
/// - Card with subtle depth (like iOS Settings grouped cells)
/// - Clean, minimal, text-forward
/// - Optional subtle icon on right (chevron)
class AppleCardButton extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback onPressed;
  final bool showChevron;

  const AppleCardButton({
    super.key,
    required this.title,
    this.subtitle,
    required this.onPressed,
    this.showChevron = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      child: Material(
        color: AppleColors.secondaryBackground,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          splashColor: AppleColors.accent.withOpacity(0.05),
          highlightColor: AppleColors.accent.withOpacity(0.02),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppleTextStyles.headline),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(subtitle!, style: AppleTextStyles.subheadline),
                      ],
                    ],
                  ),
                ),
                if (showChevron)
                  Icon(
                    Icons.chevron_right,
                    color: AppleColors.tertiaryLabel,
                    size: 22,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Apple-style text button (minimal action)
class AppleTextButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final Color? color;

  const AppleTextButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: color ?? AppleColors.accent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      child: Text(
        label,
        style: AppleTextStyles.body.copyWith(
          color: color ?? AppleColors.accent,
        ),
      ),
    );
  }
}

/// Apple-style back button (SF Symbol arrow)
class AppleBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String? label;

  const AppleBackButton({
    super.key,
    this.onPressed,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed ?? () => Navigator.pop(context),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chevron_left,
            color: AppleColors.accent,
            size: 28,
          ),
          if (label != null)
            Text(
              label!,
              style: AppleTextStyles.body.copyWith(
                color: AppleColors.accent,
              ),
            ),
        ],
      ),
    );
  }
}

/// Apple-style close button (X in circle)
class AppleCloseButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const AppleCloseButton({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed ?? () => Navigator.pop(context),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: AppleColors.systemGray5,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.close,
          size: 16,
          color: AppleColors.secondaryLabel,
        ),
      ),
    );
  }
}
