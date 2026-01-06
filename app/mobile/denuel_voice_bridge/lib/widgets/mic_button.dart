import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// MicButton - Large, calming microphone button
/// 
/// UX Purpose:
/// - Impossible to miss (140px diameter)
/// - Gentle pulse animation while listening (not alarming)
/// - Clear visual state change
/// - No harsh colors or aggressive animations
/// 
/// Accessibility:
/// - Large touch target exceeds all guidelines
/// - High contrast icon
/// - Clear state communication
/// - Animation is subtle, not distracting
class MicButton extends StatefulWidget {
  final bool isListening;
  final VoidCallback onPressed;

  const MicButton({
    super.key,
    required this.isListening,
    required this.onPressed,
  });

  @override
  State<MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<MicButton> 
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void didUpdateWidget(MicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isListening && !oldWidget.isListening) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isListening && oldWidget.isListening) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.isListening ? 'Stop recording' : 'Start recording',
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            final scale = widget.isListening ? _pulseAnimation.value : 1.0;
            return Transform.scale(
              scale: scale,
              child: child,
            );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: widget.isListening 
                  ? AppColors.listening 
                  : AppColors.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (widget.isListening 
                      ? AppColors.listening 
                      : AppColors.primary).withOpacity(0.3),
                  blurRadius: widget.isListening ? 32 : 24,
                  spreadRadius: widget.isListening ? 8 : 4,
                ),
              ],
            ),
            child: Icon(
              widget.isListening ? Icons.mic : Icons.mic_none_rounded,
              size: 56,
              color: AppColors.textOnPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Helper widget for AnimatedBuilder
class AnimatedBuilder extends StatelessWidget {
  final Animation<double> animation;
  final Widget Function(BuildContext context, Widget? child) builder;
  final Widget? child;

  const AnimatedBuilder({
    super.key,
    required this.animation,
    required this.builder,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder2(
      animation: animation,
      builder: builder,
      child: child,
    );
  }
}

class AnimatedBuilder2 extends AnimatedWidget {
  final Widget Function(BuildContext context, Widget? child) builder;
  final Widget? child;

  const AnimatedBuilder2({
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
