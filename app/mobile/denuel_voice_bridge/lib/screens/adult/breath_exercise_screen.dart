import 'package:flutter/material.dart';
import '../../theme/adult_theme.dart';
import '../../widgets/widgets.dart';

/// Breath exercise screen for anxiety reduction
class BreathExerciseScreen extends StatefulWidget {
  const BreathExerciseScreen({super.key});

  @override
  State<BreathExerciseScreen> createState() => _BreathExerciseScreenState();
}

class _BreathExerciseScreenState extends State<BreathExerciseScreen> {
  bool _isActive = false;
  bool _isComplete = false;
  int _selectedCycles = 3;

  void _startExercise() {
    setState(() {
      _isActive = true;
      _isComplete = false;
    });
  }

  void _onComplete() {
    setState(() {
      _isActive = false;
      _isComplete = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdultTheme.background,
      appBar: AppBar(
        backgroundColor: AdultTheme.background,
        title: const Text('Breath Exercise'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              if (!_isActive && !_isComplete) ...[
                // Setup
                const Spacer(),
                Icon(
                  Icons.self_improvement_rounded,
                  size: 80,
                  color: AdultTheme.primary.withOpacity(0.5),
                ),
                const SizedBox(height: 24),
                Text(
                  'Calm Your Mind',
                  style: AdultTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Take a moment to breathe deeply before your practice session.',
                  style: AdultTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),

                // Cycle selector
                Text('Number of cycles', style: AdultTheme.titleMedium),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [3, 5, 7].map((cycles) {
                    final isSelected = _selectedCycles == cycles;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedCycles = cycles),
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? AdultTheme.primary 
                                : AdultTheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected 
                                  ? AdultTheme.primary 
                                  : AdultTheme.border,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '$cycles',
                              style: AdultTheme.headlineSmall.copyWith(
                                color: isSelected 
                                    ? Colors.white 
                                    : AdultTheme.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Text(
                  '${_selectedCycles * 12} seconds total',
                  style: AdultTheme.bodySmall,
                ),

                const Spacer(),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _startExercise,
                    child: const Text('Begin Exercise'),
                  ),
                ),
              ] else if (_isActive) ...[
                // Active exercise
                const Spacer(),
                BreathCoach(
                  isActive: true,
                  cycles: _selectedCycles,
                  onComplete: _onComplete,
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isActive = false;
                    });
                  },
                  child: const Text('Stop'),
                ),
              ] else if (_isComplete) ...[
                // Complete
                const Spacer(),
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AdultTheme.success.withOpacity(0.1),
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    size: 64,
                    color: AdultTheme.success,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Well Done!',
                  style: AdultTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  'You\'re now ready for your practice session.',
                  style: AdultTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _isComplete = false;
                          });
                        },
                        child: const Text('Do Again'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Continue'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
