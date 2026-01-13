import 'dart:math';
import 'package:flutter/material.dart';
import '../../theme/child_theme.dart';

/// Sound Match Game - Match sounds with pictures
/// 
/// Simple gameplay:
/// 1. Show 4 picture options
/// 2. Play a target sound
/// 3. Child taps the matching picture
/// 4. Celebrate correct matches!
class SoundMatchGameScreen extends StatefulWidget {
  const SoundMatchGameScreen({super.key});

  @override
  State<SoundMatchGameScreen> createState() => _SoundMatchGameScreenState();
}

class _SoundMatchGameScreenState extends State<SoundMatchGameScreen>
    with SingleTickerProviderStateMixin {
  int _score = 0;
  int _round = 1;
  int _totalRounds = 5;
  int? _correctIndex;
  int? _selectedIndex;
  bool _showResult = false;
  bool _isCorrect = false;
  late List<SoundItem> _currentOptions;
  late AnimationController _celebrationController;
  
  // Sound items with emoji representations
  final List<SoundItem> _allSounds = [
    SoundItem('cat', '🐱', 'Meow! Cat'),
    SoundItem('dog', '🐕', 'Woof! Dog'),
    SoundItem('bird', '🐦', 'Tweet! Bird'),
    SoundItem('cow', '🐄', 'Moo! Cow'),
    SoundItem('lion', '🦁', 'Roar! Lion'),
    SoundItem('duck', '🦆', 'Quack! Duck'),
    SoundItem('frog', '🐸', 'Ribbit! Frog'),
    SoundItem('bee', '🐝', 'Buzz! Bee'),
    SoundItem('snake', '🐍', 'Hiss! Snake'),
    SoundItem('owl', '🦉', 'Hoot! Owl'),
    SoundItem('pig', '🐷', 'Oink! Pig'),
    SoundItem('horse', '🐴', 'Neigh! Horse'),
  ];

  @override
  void initState() {
    super.initState();
    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _startNewRound();
  }

  @override
  void dispose() {
    _celebrationController.dispose();
    super.dispose();
  }

  void _startNewRound() {
    final random = Random();
    final shuffled = List<SoundItem>.from(_allSounds)..shuffle();
    _currentOptions = shuffled.take(4).toList();
    _correctIndex = random.nextInt(4);
    _selectedIndex = null;
    _showResult = false;
    setState(() {});
    
    // Play the sound hint after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _showSoundHint();
    });
  }

  void _showSoundHint() {
    final correct = _currentOptions[_correctIndex!];
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        backgroundColor: ChildTheme.surface,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔊', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              'Find the ${correct.name}!',
              style: ChildTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              correct.soundHint,
              style: ChildTheme.titleLarge.copyWith(
                color: ChildTheme.primary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: ChildTheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              child: Text('Got it!', style: ChildTheme.titleMedium.copyWith(
                color: Colors.white,
              )),
            ),
          ),
        ],
      ),
    );
  }

  void _onOptionSelected(int index) {
    if (_showResult) return;
    
    setState(() {
      _selectedIndex = index;
      _showResult = true;
      _isCorrect = index == _correctIndex;
      
      if (_isCorrect) {
        _score += 10;
        _celebrationController.forward(from: 0);
      }
    });
    
    // Move to next round after delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        if (_round < _totalRounds) {
          setState(() => _round++);
          _startNewRound();
        } else {
          _showGameComplete();
        }
      }
    });
  }

  void _showGameComplete() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        backgroundColor: ChildTheme.surface,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              'Great Job!',
              style: ChildTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ChildTheme.secondary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    'Your Score',
                    style: ChildTheme.bodyLarge,
                  ),
                  Text(
                    '$_score',
                    style: ChildTheme.headlineLarge.copyWith(
                      color: ChildTheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _getScoreMessage(),
              style: ChildTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: Text('Done', style: ChildTheme.titleMedium),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ChildTheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    _score = 0;
                    _round = 1;
                  });
                  _startNewRound();
                },
                child: Text('Play Again!', style: ChildTheme.titleMedium.copyWith(
                  color: Colors.white,
                )),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getScoreMessage() {
    final percentage = _score / (_totalRounds * 10) * 100;
    if (percentage >= 80) return 'Amazing! You\'re a Sound Master! 🌟';
    if (percentage >= 60) return 'Good job! Keep practicing! 👍';
    if (percentage >= 40) return 'Nice try! You\'re learning! 📚';
    return 'Keep trying! You\'ll get better! 💪';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: ChildTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => Navigator.pop(context),
                      style: IconButton.styleFrom(
                        backgroundColor: ChildTheme.surface,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Sound Match', style: ChildTheme.titleLarge),
                          Text(
                            'Round $_round of $_totalRounds',
                            style: ChildTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: ChildTheme.secondary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Text('⭐', style: TextStyle(fontSize: 20)),
                          const SizedBox(width: 4),
                          Text(
                            '$_score',
                            style: ChildTheme.titleMedium.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Progress bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: _round / _totalRounds,
                    backgroundColor: ChildTheme.surface,
                    valueColor: AlwaysStoppedAnimation<Color>(ChildTheme.primary),
                    minHeight: 10,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Replay sound button
              GestureDetector(
                onTap: _showSoundHint,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: ChildTheme.surface,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: ChildTheme.primary.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Text('🔊', style: TextStyle(fontSize: 48)),
                ),
              ),
              
              const SizedBox(height: 8),
              Text(
                'Tap to hear again',
                style: ChildTheme.bodyMedium,
              ),

              const Spacer(),

              // Options grid
              Padding(
                padding: const EdgeInsets.all(24),
                child: GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  children: List.generate(4, (index) {
                    final item = _currentOptions[index];
                    final isSelected = _selectedIndex == index;
                    final isCorrect = _correctIndex == index;
                    
                    Color bgColor = ChildTheme.surface;
                    if (_showResult) {
                      if (isCorrect) {
                        bgColor = ChildTheme.success.withOpacity(0.3);
                      } else if (isSelected && !isCorrect) {
                        bgColor = ChildTheme.error.withOpacity(0.3);
                      }
                    }
                    
                    return GestureDetector(
                      onTap: () => _onOptionSelected(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isSelected 
                                ? ChildTheme.primary 
                                : Colors.transparent,
                            width: 4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              item.emoji,
                              style: const TextStyle(fontSize: 64),
                            ),
                            if (_showResult && isCorrect) ...[
                              const SizedBox(height: 8),
                              Text(
                                item.name,
                                style: ChildTheme.titleMedium.copyWith(
                                  color: ChildTheme.success,
                                ),
                              ),
                            ],
                            if (_showResult && isSelected && !isCorrect) ...[
                              const SizedBox(height: 8),
                              const Text(
                                '❌',
                                style: TextStyle(fontSize: 24),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// Data class for sound items
class SoundItem {
  final String name;
  final String emoji;
  final String soundHint;

  SoundItem(this.name, this.emoji, this.soundHint);
}
