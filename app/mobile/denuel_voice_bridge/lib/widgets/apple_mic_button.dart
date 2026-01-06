import 'package:flutter/material.dart';
import '../theme/apple_colors.dart';

/// Apple Voice Memos-inspired microphone button
/// 
/// UX Philosophy:
/// - Large, central, unmistakable purpose
/// - Soft pulsing ring while listening (like Voice Memos)
/// - No harsh animations - gentle, breathing effect
/// - Sufficient contrast for visibility
/// - 88px diameter (larger than standard, easier to tap)
class AppleMicButton extends StatefulWidget {
  final bool isListening;
  final VoidCallback onPressed;

  const AppleMicButton({
    super.key,
    required this.isListening,
    required this.onPressed,
  });

  @override
  State<AppleMicButton> createState() => _AppleMicButtonState();
}

class _AppleMicButtonState extends State<AppleMicButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.6, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(AppleMicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isListening && !oldWidget.isListening) {
      _controller.repeat();
    } else if (!widget.isListening && oldWidget.isListening) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.isListening ? 'Stop listening' : 'Start speaking',
      child: GestureDetector(
        onTap: widget.onPressed,
        child: SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Pulsing ring (only when listening)
              if (widget.isListening)
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppleColors.accent
                                .withOpacity(_opacityAnimation.value),
                            width: 3,
                          ),
                        ),
                      ),
                    );
                  },
                ),

              // Main button
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: widget.isListening
                      ? AppleColors.accent
                      : AppleColors.accent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppleColors.accent.withOpacity(0.3),
                      blurRadius: widget.isListening ? 20 : 12,
                      spreadRadius: widget.isListening ? 2 : 0,
                    ),
                  ],
                ),
                child: Icon(
                  widget.isListening ? Icons.stop_rounded : Icons.mic_none,
                  size: 36,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Helper for AnimatedBuilder
class AnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext context, Widget? child) builder;
  final Widget? child;

  const AnimatedBuilder({
    super.key,
    required Animation<double> animation,
    required this.builder,
    this.child,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    return builder(context, child);
  }
}
