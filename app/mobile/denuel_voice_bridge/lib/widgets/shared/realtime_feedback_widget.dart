import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../theme/adult_theme.dart';

/// Real-time visual feedback during speech practice
class RealtimeFeedbackWidget extends StatefulWidget {
  final bool isActive;
  final double nasalityLevel; // 0-100, lower is better
  final double clarityLevel; // 0-100, higher is better
  final double volumeLevel; // 0-100
  final double pacingScore; // 0-100

  const RealtimeFeedbackWidget({
    super.key,
    required this.isActive,
    this.nasalityLevel = 30,
    this.clarityLevel = 75,
    this.volumeLevel = 60,
    this.pacingScore = 80,
  });

  @override
  State<RealtimeFeedbackWidget> createState() => _RealtimeFeedbackWidgetState();
}

class _RealtimeFeedbackWidgetState extends State<RealtimeFeedbackWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AdultTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AdultTheme.border),
        boxShadow: AdultTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AdultTheme.success.withOpacity(0.5 + _pulseController.value * 0.5),
                      shape: BoxShape.circle,
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              Text('Live Feedback', style: AdultTheme.labelLarge),
            ],
          ),
          const SizedBox(height: 20),

          // Nasality indicator (want this LOW)
          _FeedbackBar(
            label: 'Nasal Airflow',
            value: widget.nasalityLevel,
            isInverted: true, // Lower is better
            icon: Icons.air,
            goodLabel: 'Good',
            badLabel: 'High',
          ),
          const SizedBox(height: 16),

          // Clarity indicator (want this HIGH)
          _FeedbackBar(
            label: 'Clarity',
            value: widget.clarityLevel,
            isInverted: false, // Higher is better
            icon: Icons.graphic_eq,
            goodLabel: 'Clear',
            badLabel: 'Unclear',
          ),
          const SizedBox(height: 16),

          // Volume indicator
          _FeedbackBar(
            label: 'Volume',
            value: widget.volumeLevel,
            isInverted: false,
            icon: Icons.volume_up,
            goodLabel: 'Good',
            badLabel: 'Low',
            showMiddleZone: true,
          ),
          const SizedBox(height: 16),

          // Pacing indicator
          _FeedbackBar(
            label: 'Pacing',
            value: widget.pacingScore,
            isInverted: false,
            icon: Icons.speed,
            goodLabel: 'Steady',
            badLabel: 'Rushed',
          ),

          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),

          // Quick tip based on current metrics
          _QuickTipWidget(
            nasality: widget.nasalityLevel,
            clarity: widget.clarityLevel,
            volume: widget.volumeLevel,
            pacing: widget.pacingScore,
          ),
        ],
      ),
    );
  }
}

class _FeedbackBar extends StatelessWidget {
  final String label;
  final double value;
  final bool isInverted;
  final IconData icon;
  final String goodLabel;
  final String badLabel;
  final bool showMiddleZone;

  const _FeedbackBar({
    required this.label,
    required this.value,
    required this.isInverted,
    required this.icon,
    required this.goodLabel,
    required this.badLabel,
    this.showMiddleZone = false,
  });

  Color _getColor() {
    final effectiveValue = isInverted ? 100 - value : value;
    if (effectiveValue >= 70) return AdultTheme.success;
    if (effectiveValue >= 40) return AdultTheme.warning;
    return AdultTheme.error;
  }

  String _getStatus() {
    final effectiveValue = isInverted ? 100 - value : value;
    if (effectiveValue >= 70) return goodLabel;
    if (effectiveValue >= 40) return 'Okay';
    return badLabel;
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor();
    final displayValue = isInverted ? 100 - value : value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: AdultTheme.textTertiary),
                const SizedBox(width: 8),
                Text(label, style: AdultTheme.labelMedium),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _getStatus(),
                style: AdultTheme.bodySmall.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            // Background
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: AdultTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            // Progress
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 8,
              width: (displayValue / 100) * 200,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            // Target zone indicator (for volume)
            if (showMiddleZone)
              Positioned(
                left: 100,
                child: Container(
                  width: 60,
                  height: 8,
                  decoration: BoxDecoration(
                    border: Border.all(color: AdultTheme.success, width: 2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _QuickTipWidget extends StatelessWidget {
  final double nasality;
  final double clarity;
  final double volume;
  final double pacing;

  const _QuickTipWidget({
    required this.nasality,
    required this.clarity,
    required this.volume,
    required this.pacing,
  });

  String _getTip() {
    // Check nasality first (most important for cleft palate)
    if (nasality > 60) {
      return '💡 Try closing your soft palate more. Take a breath through your nose, then speak through your mouth.';
    }
    if (clarity < 50) {
      return '💡 Slow down and focus on clear articulation. Exaggerate your mouth movements.';
    }
    if (volume < 40) {
      return '💡 Project your voice a bit more. Take a deeper breath before speaking.';
    }
    if (pacing < 50) {
      return '💡 You\'re speaking quickly. Try pausing between phrases.';
    }
    // All good
    return '✨ Great job! Your speech is clear and well-paced. Keep it up!';
  }

  @override
  Widget build(BuildContext context) {
    final tip = _getTip();
    final isPositive = tip.startsWith('✨');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isPositive
            ? AdultTheme.success.withOpacity(0.1)
            : AdultTheme.info.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              tip,
              style: AdultTheme.bodySmall.copyWith(
                color: isPositive ? AdultTheme.success : AdultTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated speech visualization showing sound formation
class SpeechVisualization extends StatefulWidget {
  final bool isActive;
  final List<double> amplitudes;

  const SpeechVisualization({
    super.key,
    required this.isActive,
    this.amplitudes = const [],
  });

  @override
  State<SpeechVisualization> createState() => _SpeechVisualizationState();
}

class _SpeechVisualizationState extends State<SpeechVisualization>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    if (widget.isActive) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(SpeechVisualization oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isActive && _controller.isAnimating) {
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
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: AdultTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdultTheme.border),
      ),
      child: CustomPaint(
        painter: _WavePainter(
          amplitudes: widget.amplitudes,
          color: AdultTheme.primary,
          isActive: widget.isActive,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final List<double> amplitudes;
  final Color color;
  final bool isActive;

  _WavePainter({
    required this.amplitudes,
    required this.color,
    required this.isActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!isActive) {
      // Draw flat line when not active
      final paint = Paint()
        ..color = color.withOpacity(0.3)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      canvas.drawLine(
        Offset(0, size.height / 2),
        Offset(size.width, size.height / 2),
        paint,
      );
      return;
    }

    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final barWidth = size.width / 30;
    final random = Random();

    path.moveTo(0, size.height / 2);

    for (int i = 0; i < 30; i++) {
      final amplitude = amplitudes.isNotEmpty && i < amplitudes.length
          ? amplitudes[i]
          : (random.nextDouble() * 0.6 + 0.2);
      
      final x = i * barWidth + barWidth / 2;
      final y = size.height / 2 - (amplitude * size.height * 0.4);
      
      if (i == 0) {
        path.lineTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);

    // Draw mirrored path
    final mirrorPath = Path();
    mirrorPath.moveTo(0, size.height / 2);

    for (int i = 0; i < 30; i++) {
      final amplitude = amplitudes.isNotEmpty && i < amplitudes.length
          ? amplitudes[i]
          : (random.nextDouble() * 0.6 + 0.2);
      
      final x = i * barWidth + barWidth / 2;
      final y = size.height / 2 + (amplitude * size.height * 0.4);
      
      mirrorPath.lineTo(x, y);
    }

    paint.color = color.withOpacity(0.5);
    canvas.drawPath(mirrorPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
