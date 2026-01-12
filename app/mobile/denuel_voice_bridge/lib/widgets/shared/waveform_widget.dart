import 'dart:math';
import 'package:flutter/material.dart';
import '../../theme/adult_theme.dart';

/// Animated waveform visualization widget
class WaveformWidget extends StatefulWidget {
  final bool isActive;
  final Color? color;
  final double height;
  final int barCount;
  final List<double>? audioLevels;

  const WaveformWidget({
    super.key,
    this.isActive = false,
    this.color,
    this.height = 60,
    this.barCount = 40,
    this.audioLevels,
  });

  @override
  State<WaveformWidget> createState() => _WaveformWidgetState();
}

class _WaveformWidgetState extends State<WaveformWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<double> _heights;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _heights = List.generate(widget.barCount, (_) => 0.3);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    )..addListener(_updateHeights);

    if (widget.isActive) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(WaveformWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _controller.repeat();
    } else if (!widget.isActive && oldWidget.isActive) {
      _controller.stop();
      setState(() {
        _heights = List.generate(widget.barCount, (_) => 0.3);
      });
    }

    if (widget.audioLevels != null) {
      setState(() {
        _heights = widget.audioLevels!;
      });
    }
  }

  void _updateHeights() {
    if (!widget.isActive) return;
    if (widget.audioLevels != null) return;

    setState(() {
      for (int i = 0; i < _heights.length; i++) {
        // Simulate audio activity
        final target = 0.2 + _random.nextDouble() * 0.8;
        _heights[i] = _heights[i] + (target - _heights[i]) * 0.3;
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final barColor = widget.color ?? AdultTheme.primary;

    return SizedBox(
      height: widget.height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(widget.barCount, (index) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: 3,
            height: widget.height * _heights[index],
            decoration: BoxDecoration(
              color: barColor.withOpacity(0.3 + _heights[index] * 0.7),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ),
    );
  }
}

/// Circular waveform for mic button
class CircularWaveform extends StatefulWidget {
  final bool isActive;
  final Color color;
  final double size;

  const CircularWaveform({
    super.key,
    this.isActive = false,
    required this.color,
    this.size = 120,
  });

  @override
  State<CircularWaveform> createState() => _CircularWaveformState();
}

class _CircularWaveformState extends State<CircularWaveform>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.isActive) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(CircularWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isActive && oldWidget.isActive) {
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
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer ring
            if (widget.isActive)
              Container(
                width: widget.size * _pulseAnimation.value,
                height: widget.size * _pulseAnimation.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.color.withOpacity(0.2),
                    width: 2,
                  ),
                ),
              ),
            // Middle ring
            if (widget.isActive)
              Container(
                width: widget.size * (_pulseAnimation.value - 0.15),
                height: widget.size * (_pulseAnimation.value - 0.15),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.color.withOpacity(0.3),
                    width: 3,
                  ),
                ),
              ),
            // Inner circle
            Container(
              width: widget.size * 0.7,
              height: widget.size * 0.7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color,
                boxShadow: widget.isActive
                    ? [
                        BoxShadow(
                          color: widget.color.withOpacity(0.4),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ]
                    : null,
              ),
            ),
          ],
        );
      },
    );
  }
}
