import 'package:flutter/material.dart';
import '../theme/apple_colors.dart';
import '../theme/apple_text_styles.dart';

/// Apple iOS Settings-style list row
/// 
/// UX Philosophy:
/// - Clean, minimal design like iOS Settings
/// - Consistent padding and spacing
/// - Optional leading icon/avatar
/// - Optional trailing chevron or accessory
/// - Subtle separator
class AppleListRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showSeparator;

  const AppleListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.showSeparator = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: AppleColors.secondaryBackground,
          child: InkWell(
            onTap: onTap,
            splashColor: AppleColors.accent.withOpacity(0.05),
            highlightColor: AppleColors.accent.withOpacity(0.02),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(width: 16),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: AppleTextStyles.body),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(subtitle!, style: AppleTextStyles.footnote),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null)
                    trailing!
                  else if (onTap != null)
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
        if (showSeparator)
          Container(
            margin: EdgeInsets.only(left: leading != null ? 60 : 20),
            height: 0.5,
            color: AppleColors.opaqueSeparator,
          ),
      ],
    );
  }
}

/// Apple-style grouped section with header
class AppleGroupedSection extends StatelessWidget {
  final String? header;
  final String? footer;
  final List<Widget> children;

  const AppleGroupedSection({
    super.key,
    this.header,
    this.footer,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (header != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            child: Text(
              header!.toUpperCase(),
              style: AppleTextStyles.footnote.copyWith(
                color: AppleColors.secondaryLabel,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            color: AppleColors.secondaryBackground,
            child: Column(
              children: List.generate(children.length, (index) {
                final child = children[index];
                if (child is AppleListRow) {
                  return AppleListRow(
                    title: child.title,
                    subtitle: child.subtitle,
                    leading: child.leading,
                    trailing: child.trailing,
                    onTap: child.onTap,
                    showSeparator: index < children.length - 1,
                  );
                }
                return child;
              }),
            ),
          ),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Text(
              footer!,
              style: AppleTextStyles.footnote,
            ),
          ),
      ],
    );
  }
}

/// Apple-style avatar circle with initial
class AppleAvatar extends StatelessWidget {
  final String initial;
  final double size;
  final bool isActive;
  final Color? backgroundColor;

  const AppleAvatar({
    super.key,
    required this.initial,
    this.size = 40,
    this.isActive = false,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? (isActive ? AppleColors.accentLight : AppleColors.systemGray5),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial.isNotEmpty ? initial.toUpperCase() : '?',
          style: AppleTextStyles.headline.copyWith(
            color: isActive ? AppleColors.accent : AppleColors.secondaryLabel,
            fontSize: size * 0.4,
          ),
        ),
      ),
    );
  }
}
