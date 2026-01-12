import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/adult_theme.dart';

/// Breath coaching widget with visual biofeedback
class BreathCoach extends StatefulWidget {
  final bool isActive;
  final int inhaleDuration; // seconds
  final int holdDuration; // seconds
  final int exhaleDuration; // seconds
  final VoidCallback? onComplete;
  final int cycles;

  const BreathCoach({
    super.key,
    this.isActive = false,
    this.inhaleDuration = 4,
    this.holdDuration = 4,
    this.exhaleDuration = 4,
    this.onComplete,
    this.cycles = 3,
  });

  @override
  State<BreathCoach> createState() => _BreathCoachState();
}

class _BreathCoachState extends State<BreathCoach>
    with TickerProviderStateMixin {
  late AnimationController _breathController;
  late Animation<double> _breathAnimation;
  
  BreathPhase _currentPhase = BreathPhase.inhale;
  int _currentCycle = 1;
  Timer? _phaseTimer;
  String _instruction = 'Breathe In';

  @override
  void initState() {
    super.initState();
    _breathController = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.inhaleDuration),
    );
    _breathAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOut),
    );

    if (widget.isActive) {
      _startBreathing();
    }
  }

  @override
  void didUpdateWidget(BreathCoach oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _startBreathing();
    } else if (!widget.isActive && oldWidget.isActive) {
      _stopBreathing();
    }
  }

  void _startBreathing() {
    _currentCycle = 1;
    _startPhase(BreathPhase.inhale);
  }

  void _stopBreathing() {
    _phaseTimer?.cancel();
    _breathController.stop();
    _breathController.reset();
  }

  void _startPhase(BreathPhase phase) {
    setState(() {
      _currentPhase = phase;
      _instruction = phase.instruction;
    });

    _breathController.duration = Duration(seconds: _getPhaseDuration(phase));

    switch (phase) {
      case BreathPhase.inhale:
        _breathController.forward(from: 0);
        break;
      case BreathPhase.hold:
        // Keep at max
        break;
      case BreathPhase.exhale:
        _breathController.reverse(from: 1);
        break;
    }

    _phaseTimer = Timer(Duration(seconds: _getPhaseDuration(phase)), () {
      _nextPhase();
    });
  }

  void _nextPhase() {
    switch (_currentPhase) {
      case BreathPhase.inhale:
        _startPhase(BreathPhase.hold);
        break;
      case BreathPhase.hold:
        _startPhase(BreathPhase.exhale);
        break;
      case BreathPhase.exhale:
        if (_currentCycle < widget.cycles) {
          _currentCycle++;
          _startPhase(BreathPhase.inhale);
        } else {
          widget.onComplete?.call();
          _stopBreathing();
        }
        break;
    }
  }

  int _getPhaseDuration(BreathPhase phase) {
    switch (phase) {
      case BreathPhase.inhale:
        return widget.inhaleDuration;
      case BreathPhase.hold:
        return widget.holdDuration;
      case BreathPhase.exhale:
        return widget.exhaleDuration;
    }
  }

  @override
  void dispose() {
    _phaseTimer?.cancel();
    _breathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Breath circle
        AnimatedBuilder(
          animation: _breathAnimation,
          builder: (context, child) {
            return Container(
              width: 200 * _breathAnimation.value,
              height: 200 * _breathAnimation.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _getPhaseColor().withOpacity(0.8),
                    _getPhaseColor().withOpacity(0.3),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _getPhaseColor().withOpacity(0.3),
                    blurRadius: 30,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  _getPhaseIcon(),
                  size: 48,
                  color: Colors.white,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 32),
        
        // Instruction
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            _instruction,
            key: ValueKey(_instruction),
            style: AdultTheme.headlineMedium.copyWith(
              color: _getPhaseColor(),
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Cycle indicator
        Text(
          'Cycle $_currentCycle of ${widget.cycles}',
          style: AdultTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        
        // Phase dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: BreathPhase.values.map((phase) {
            final isActive = phase == _currentPhase;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isActive 
                    ? _getPhaseColor() 
                    : AdultTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                phase.label,
                style: AdultTheme.labelMedium.copyWith(
                  color: isActive ? Colors.white : AdultTheme.textTertiary,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Color _getPhaseColor() {
    switch (_currentPhase) {
      case BreathPhase.inhale:
        return AdultTheme.info;
      case BreathPhase.hold:
        return AdultTheme.warning;
      case BreathPhase.exhale:
        return AdultTheme.success;
    }
  }

  IconData _getPhaseIcon() {
    switch (_currentPhase) {
      case BreathPhase.inhale:
        return Icons.arrow_downward_rounded;
      case BreathPhase.hold:
        return Icons.pause_rounded;
      case BreathPhase.exhale:
        return Icons.arrow_upward_rounded;
    }
  }
}

enum BreathPhase {
  inhale,
  hold,
  exhale,
}

extension BreathPhaseExtension on BreathPhase {
  String get label {
    switch (this) {
      case BreathPhase.inhale:
        return 'Inhale';
      case BreathPhase.hold:
        return 'Hold';
      case BreathPhase.exhale:
        return 'Exhale';
    }
  }

  String get instruction {
    switch (this) {
      case BreathPhase.inhale:
        return 'Breathe In';
      case BreathPhase.hold:
        return 'Hold';
      case BreathPhase.exhale:
        return 'Breathe Out';
    }
  }
}

/// Compact breath indicator
class BreathIndicator extends StatelessWidget {
  final double level; // 0-1
  final Color? color;

  const BreathIndicator({
    super.key,
    required this.level,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AdultTheme.primary;

    return Container(
      width: 60,
      height: 120,
      decoration: BoxDecoration(
        color: AdultTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AdultTheme.border),
      ),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 60,
            height: 120 * level,
            decoration: BoxDecoration(
              color: effectiveColor.withOpacity(0.3),
              borderRadius: BorderRadius.circular(30),
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  effectiveColor,
                  effectiveColor.withOpacity(0.5),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 8,
            child: Icon(
              Icons.air_rounded,
              color: level > 0.3 ? Colors.white : effectiveColor,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}
