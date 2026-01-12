import 'package:flutter/material.dart';
import '../../theme/child_theme.dart';

/// Friendly avatar widget for Child Mode
class FriendlyAvatar extends StatefulWidget {
  final String expression;
  final double size;
  final bool isAnimated;
  final bool isSpeaking;

  const FriendlyAvatar({
    super.key,
    this.expression = 'happy',
    this.size = 120,
    this.isAnimated = true,
    this.isSpeaking = false,
  });

  @override
  State<FriendlyAvatar> createState() => _FriendlyAvatarState();
}

class _FriendlyAvatarState extends State<FriendlyAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _bounceAnimation = Tween<double>(begin: 0, end: 8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.isAnimated) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(FriendlyAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAnimated && !oldWidget.isAnimated) {
      _controller.repeat(reverse: true);
    } else if (!widget.isAnimated && oldWidget.isAnimated) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final emoji = ChildTheme.avatarEmojis[widget.expression] ?? '😊';

    return AnimatedBuilder(
      animation: _bounceAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -_bounceAnimation.value),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Glow effect
              Container(
                width: widget.size * 1.2,
                height: widget.size * 1.2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: ChildTheme.primary.withOpacity(0.2),
                      blurRadius: 30,
                      spreadRadius: 10,
                    ),
                  ],
                ),
              ),
              // Avatar circle
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: ChildTheme.primaryGradient,
                  boxShadow: [
                    BoxShadow(
                      color: ChildTheme.primary.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    emoji,
                    style: TextStyle(fontSize: widget.size * 0.5),
                  ),
                ),
              ),
              // Speaking indicator
              if (widget.isSpeaking)
                Positioned(
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: ChildTheme.success,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.volume_up_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Speaking',
                          style: ChildTheme.bodySmall.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Speech bubble for avatar messages
class SpeechBubble extends StatelessWidget {
  final String text;
  final bool isLeft;

  const SpeechBubble({
    super.key,
    required this.text,
    this.isLeft = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: EdgeInsets.only(
        left: isLeft ? 0 : 40,
        right: isLeft ? 40 : 0,
      ),
      decoration: BoxDecoration(
        color: ChildTheme.surface,
        borderRadius: BorderRadius.circular(ChildTheme.radiusLarge),
        boxShadow: ChildTheme.cardShadow,
      ),
      child: Text(
        text,
        style: ChildTheme.avatarSpeech,
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// Star rating display
class StarRating extends StatelessWidget {
  final int stars;
  final int maxStars;
  final double size;
  final bool animated;

  const StarRating({
    super.key,
    required this.stars,
    this.maxStars = 3,
    this.size = 32,
    this.animated = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(maxStars, (index) {
        final isFilled = index < stars;
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: isFilled ? 1 : 0),
          duration: Duration(milliseconds: animated ? 300 + (index * 200) : 0),
          builder: (context, value, child) {
            return Transform.scale(
              scale: 0.5 + (value * 0.5),
              child: Icon(
                isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
                color: isFilled ? ChildTheme.star : ChildTheme.border,
                size: size,
              ),
            );
          },
        );
      }),
    );
  }
}

/// Progress bar with fun styling
class FunProgressBar extends StatelessWidget {
  final double progress; // 0-1
  final Color? color;
  final double height;
  final String? label;

  const FunProgressBar({
    super.key,
    required this.progress,
    this.color,
    this.height = 16,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? ChildTheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label!, style: ChildTheme.bodyMedium),
              Text(
                '${(progress * 100).toInt()}%',
                style: ChildTheme.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: effectiveColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Stack(
          children: [
            // Background
            Container(
              height: height,
              decoration: BoxDecoration(
                color: effectiveColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(height / 2),
              ),
            ),
            // Progress
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              height: height,
              width: double.infinity,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress.clamp(0, 1),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        effectiveColor,
                        effectiveColor.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(height / 2),
                    boxShadow: [
                      BoxShadow(
                        color: effectiveColor.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
