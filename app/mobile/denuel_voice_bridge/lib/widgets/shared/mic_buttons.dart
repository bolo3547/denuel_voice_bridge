import 'package:flutter/material.dart';
import '../../theme/adult_theme.dart';
import '../../theme/child_theme.dart';
import 'waveform_widget.dart';

/// Professional mic button for Adult Mode
class AdultMicButton extends StatefulWidget {
  final bool isRecording;
  final VoidCallback? onTap;
  final VoidCallback? onLongPressStart;
  final VoidCallback? onLongPressEnd;
  final double size;

  const AdultMicButton({
    super.key,
    this.isRecording = false,
    this.onTap,
    this.onLongPressStart,
    this.onLongPressEnd,
    this.size = 80,
  });

  @override
  State<AdultMicButton> createState() => _AdultMicButtonState();
}

class _AdultMicButtonState extends State<AdultMicButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onLongPressStart: (_) {
        _controller.forward();
        widget.onLongPressStart?.call();
      },
      onLongPressEnd: (_) {
        _controller.reverse();
        widget.onLongPressEnd?.call();
      },
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Pulsing rings when recording
                if (widget.isRecording)
                  CircularWaveform(
                    isActive: widget.isRecording,
                    color: AdultTheme.error,
                    size: widget.size * 1.5,
                  ),
                // Main button
                Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.isRecording 
                        ? AdultTheme.error 
                        : AdultTheme.primary,
                    boxShadow: [
                      BoxShadow(
                        color: (widget.isRecording 
                            ? AdultTheme.error 
                            : AdultTheme.primary).withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    widget.isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                    color: Colors.white,
                    size: widget.size * 0.4,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Fun, large mic button for Child Mode
class ChildMicButton extends StatefulWidget {
  final bool isRecording;
  final VoidCallback? onTap;
  final double size;
  final String? emoji;

  const ChildMicButton({
    super.key,
    this.isRecording = false,
    this.onTap,
    this.size = 120,
    this.emoji,
  });

  @override
  State<ChildMicButton> createState() => _ChildMicButtonState();
}

class _ChildMicButtonState extends State<ChildMicButton>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _bounceController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _bounceAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );

    if (widget.isRecording) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(ChildMicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording && !oldWidget.isRecording) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isRecording && oldWidget.isRecording) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _bounceController.forward(),
      onTapUp: (_) => _bounceController.reverse(),
      onTapCancel: () => _bounceController.reverse(),
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseAnimation, _bounceAnimation]),
        builder: (context, child) {
          final scale = _pulseAnimation.value * _bounceAnimation.value;
          return Transform.scale(
            scale: scale,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: widget.isRecording
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFF472B6), Color(0xFFEC4899)],
                      )
                    : ChildTheme.primaryGradient,
                boxShadow: [
                  BoxShadow(
                    color: (widget.isRecording 
                        ? ChildTheme.accent 
                        : ChildTheme.primary).withOpacity(0.4),
                    blurRadius: widget.isRecording ? 30 : 20,
                    spreadRadius: widget.isRecording ? 5 : 0,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.emoji != null)
                    Text(
                      widget.emoji!,
                      style: const TextStyle(fontSize: 32),
                    )
                  else
                    Icon(
                      widget.isRecording 
                          ? Icons.stop_rounded 
                          : Icons.mic_rounded,
                      color: Colors.white,
                      size: widget.size * 0.35,
                    ),
                  if (!widget.isRecording)
                    Text(
                      'Tap!',
                      style: ChildTheme.bodyMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Recording indicator bar
class RecordingIndicator extends StatelessWidget {
  final Duration duration;
  final bool isRecording;

  const RecordingIndicator({
    super.key,
    required this.duration,
    required this.isRecording,
  });

  @override
  Widget build(BuildContext context) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isRecording 
            ? AdultTheme.error.withOpacity(0.1) 
            : AdultTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isRecording ? AdultTheme.error : AdultTheme.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isRecording)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 8),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AdultTheme.error,
              ),
            ),
          Text(
            '$minutes:$seconds',
            style: AdultTheme.titleMedium.copyWith(
              color: isRecording ? AdultTheme.error : AdultTheme.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
