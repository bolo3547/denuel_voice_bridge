import 'dart:async';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../../theme/adult_theme.dart';
import '../../widgets/widgets.dart';

/// Targeted phoneme practice for sounds commonly affected by cleft palate
class PhonemePracticeScreen extends StatefulWidget {
  const PhonemePracticeScreen({super.key});

  @override
  State<PhonemePracticeScreen> createState() => _PhonemePracticeScreenState();
}

class _PhonemePracticeScreenState extends State<PhonemePracticeScreen> {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  int _selectedCategoryIndex = 0;
  int _currentWordIndex = 0;
  String? _recordingPath;

  // Phoneme categories commonly affected by cleft palate
  final List<PhonemeCategory> _categories = [
    PhonemeCategory(
      name: 'Bilabial Sounds',
      phonemes: ['P', 'B', 'M'],
      description: 'Sounds made with both lips together',
      icon: '👄',
      color: const Color(0xFF6366F1),
      tips: [
        'Press your lips firmly together before releasing the sound',
        'Feel the air pressure build up behind your lips',
        'Practice in front of a mirror to see lip closure',
      ],
      words: [
        PhonemeWord(word: 'Pop', phoneme: 'P', position: 'initial'),
        PhonemeWord(word: 'Baby', phoneme: 'B', position: 'initial'),
        PhonemeWord(word: 'Mama', phoneme: 'M', position: 'initial'),
        PhonemeWord(word: 'Apple', phoneme: 'P', position: 'middle'),
        PhonemeWord(word: 'Rabbit', phoneme: 'B', position: 'middle'),
        PhonemeWord(word: 'Hammer', phoneme: 'M', position: 'middle'),
        PhonemeWord(word: 'Cup', phoneme: 'P', position: 'final'),
        PhonemeWord(word: 'Cab', phoneme: 'B', position: 'final'),
        PhonemeWord(word: 'Room', phoneme: 'M', position: 'final'),
      ],
    ),
    PhonemeCategory(
      name: 'Alveolar Sounds',
      phonemes: ['T', 'D', 'N'],
      description: 'Sounds made with tongue touching the ridge behind teeth',
      icon: '👅',
      color: const Color(0xFF10B981),
      tips: [
        'Place tongue tip firmly on the ridge behind your upper teeth',
        'Keep the sides of your tongue against your upper molars',
        'Release the air through your mouth, not your nose',
      ],
      words: [
        PhonemeWord(word: 'Top', phoneme: 'T', position: 'initial'),
        PhonemeWord(word: 'Dog', phoneme: 'D', position: 'initial'),
        PhonemeWord(word: 'Nose', phoneme: 'N', position: 'initial'),
        PhonemeWord(word: 'Water', phoneme: 'T', position: 'middle'),
        PhonemeWord(word: 'Ladder', phoneme: 'D', position: 'middle'),
        PhonemeWord(word: 'Funny', phoneme: 'N', position: 'middle'),
        PhonemeWord(word: 'Cat', phoneme: 'T', position: 'final'),
        PhonemeWord(word: 'Bed', phoneme: 'D', position: 'final'),
        PhonemeWord(word: 'Sun', phoneme: 'N', position: 'final'),
      ],
    ),
    PhonemeCategory(
      name: 'Velar Sounds',
      phonemes: ['K', 'G'],
      description: 'Sounds made with back of tongue touching soft palate',
      icon: '🔊',
      color: const Color(0xFFF59E0B),
      tips: [
        'Lift the back of your tongue to touch your soft palate',
        'Feel the air stop completely before releasing',
        'Start with words where K/G come at the end (easier)',
      ],
      words: [
        PhonemeWord(word: 'Cat', phoneme: 'K', position: 'initial'),
        PhonemeWord(word: 'Go', phoneme: 'G', position: 'initial'),
        PhonemeWord(word: 'Cookie', phoneme: 'K', position: 'middle'),
        PhonemeWord(word: 'Bigger', phoneme: 'G', position: 'middle'),
        PhonemeWord(word: 'Book', phoneme: 'K', position: 'final'),
        PhonemeWord(word: 'Dog', phoneme: 'G', position: 'final'),
      ],
    ),
    PhonemeCategory(
      name: 'Fricative Sounds',
      phonemes: ['S', 'Z', 'F', 'V'],
      description: 'Sounds made by pushing air through a narrow gap',
      icon: '💨',
      color: const Color(0xFFEC4899),
      tips: [
        'Keep your tongue in position and let air flow continuously',
        'Feel the vibration for voiced sounds (Z, V)',
        'Practice making the sound longer before adding vowels',
      ],
      words: [
        PhonemeWord(word: 'Sun', phoneme: 'S', position: 'initial'),
        PhonemeWord(word: 'Zoo', phoneme: 'Z', position: 'initial'),
        PhonemeWord(word: 'Fan', phoneme: 'F', position: 'initial'),
        PhonemeWord(word: 'Van', phoneme: 'V', position: 'initial'),
        PhonemeWord(word: 'Messy', phoneme: 'S', position: 'middle'),
        PhonemeWord(word: 'Fizzy', phoneme: 'Z', position: 'middle'),
        PhonemeWord(word: 'Bus', phoneme: 'S', position: 'final'),
        PhonemeWord(word: 'Buzz', phoneme: 'Z', position: 'final'),
      ],
    ),
  ];

  PhonemeCategory get _currentCategory => _categories[_selectedCategoryIndex];
  PhonemeWord get _currentWord => _currentCategory.words[_currentWordIndex];

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) return;

    final dir = await getApplicationDocumentsDirectory();
    _recordingPath = '${dir.path}/phoneme_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: _recordingPath!,
    );

    setState(() => _isRecording = true);
  }

  Future<void> _stopRecording() async {
    await _recorder.stop();
    setState(() => _isRecording = false);
    
    // Show feedback dialog
    _showFeedbackDialog();
  }

  void _showFeedbackDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: AdultTheme.success),
            const SizedBox(width: 12),
            Text('Great Practice!', style: AdultTheme.titleLarge),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You practiced: "${_currentWord.word}"', style: AdultTheme.bodyLarge),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AdultTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('💡 Tip:', style: AdultTheme.labelLarge),
                  const SizedBox(height: 4),
                  Text(
                    _currentCategory.tips[_currentWordIndex % _currentCategory.tips.length],
                    style: AdultTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _previousWord();
            },
            child: const Text('Try Again'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _nextWord();
            },
            child: const Text('Next Word'),
          ),
        ],
      ),
    );
  }

  void _nextWord() {
    setState(() {
      if (_currentWordIndex < _currentCategory.words.length - 1) {
        _currentWordIndex++;
      } else {
        _currentWordIndex = 0;
      }
    });
  }

  void _previousWord() {
    setState(() {
      if (_currentWordIndex > 0) {
        _currentWordIndex--;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdultTheme.background,
      appBar: AppBar(
        title: const Text('Phoneme Practice'),
        backgroundColor: AdultTheme.background,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showInfoDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Category selector
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final isSelected = index == _selectedCategoryIndex;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _selectedCategoryIndex = index;
                      _currentWordIndex = 0;
                    }),
                    child: Container(
                      width: 100,
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected ? category.color.withOpacity(0.15) : AdultTheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? category.color : AdultTheme.border,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(category.icon, style: const TextStyle(fontSize: 28)),
                          const SizedBox(height: 4),
                          Text(
                            category.phonemes.join(' '),
                            style: AdultTheme.labelMedium.copyWith(
                              color: isSelected ? category.color : AdultTheme.textSecondary,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Category description
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _currentCategory.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_currentCategory.name, style: AdultTheme.titleMedium),
                    Text(_currentCategory.description, style: AdultTheme.bodySmall),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Word display
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Progress indicator
                    Text(
                      'Word ${_currentWordIndex + 1} of ${_currentCategory.words.length}',
                      style: AdultTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: (_currentWordIndex + 1) / _currentCategory.words.length,
                      backgroundColor: AdultTheme.border,
                      valueColor: AlwaysStoppedAnimation(_currentCategory.color),
                    ),
                    const SizedBox(height: 32),

                    // Current word card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: AdultTheme.surface,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: AdultTheme.cardShadowElevated,
                      ),
                      child: Column(
                        children: [
                          // Phoneme badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: _currentCategory.color.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Sound: ${_currentWord.phoneme}',
                              style: AdultTheme.labelLarge.copyWith(color: _currentCategory.color),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Word
                          Text(
                            _currentWord.word,
                            style: AdultTheme.headlineLarge.copyWith(
                              fontSize: 48,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Position hint
                          Text(
                            '${_currentWord.phoneme} at ${_currentWord.position} position',
                            style: AdultTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Recording button
                    AdultMicButton(
                      isRecording: _isRecording,
                      onTap: _isRecording ? _stopRecording : _startRecording,
                      size: 80,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isRecording ? 'Tap to stop' : 'Tap and say the word',
                      style: AdultTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),

            // Navigation
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _currentWordIndex > 0 ? _previousWord : null,
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Previous'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _nextWord,
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Next'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('About Phoneme Practice', style: AdultTheme.titleLarge),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This practice focuses on sounds that are commonly challenging for people with cleft palate.',
                style: AdultTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              _InfoItem(
                icon: '👄',
                title: 'Bilabial (P, B, M)',
                text: 'Require good lip closure',
              ),
              _InfoItem(
                icon: '👅',
                title: 'Alveolar (T, D, N)',
                text: 'Need tongue-to-ridge contact',
              ),
              _InfoItem(
                icon: '🔊',
                title: 'Velar (K, G)',
                text: 'Involve soft palate movement',
              ),
              _InfoItem(
                icon: '💨',
                title: 'Fricatives (S, Z, F, V)',
                text: 'Require controlled airflow',
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AdultTheme.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb, color: AdultTheme.info),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Practice each sound in different word positions for best results.',
                        style: AdultTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final String icon;
  final String title;
  final String text;

  const _InfoItem({required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AdultTheme.labelMedium),
                Text(text, style: AdultTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Data classes
class PhonemeCategory {
  final String name;
  final List<String> phonemes;
  final String description;
  final String icon;
  final Color color;
  final List<String> tips;
  final List<PhonemeWord> words;

  PhonemeCategory({
    required this.name,
    required this.phonemes,
    required this.description,
    required this.icon,
    required this.color,
    required this.tips,
    required this.words,
  });
}

class PhonemeWord {
  final String word;
  final String phoneme;
  final String position; // initial, middle, final

  PhonemeWord({
    required this.word,
    required this.phoneme,
    required this.position,
  });
}
