import 'package:flutter/material.dart';
import '../../theme/apple_colors.dart';
import '../../theme/apple_text_styles.dart';
import '../../widgets/apple_buttons.dart';

/// PRACTICE WITH NOTES - Apple Books Style
/// 
/// UX Philosophy:
/// - Calm, readable text presentation
/// - User controls the pace entirely
/// - No pressure, no scoring
/// - Scrollable list of practice phrases
/// - Subtle visual feedback
/// 
/// Apple Inspiration:
/// - Apple Books reading interface
/// - Notes app simplicity
/// - iOS Accessibility Speech Controller
class ApplePracticeScreen extends StatefulWidget {
  const ApplePracticeScreen({super.key});

  @override
  State<ApplePracticeScreen> createState() => _ApplePracticeScreenState();
}

class _ApplePracticeScreenState extends State<ApplePracticeScreen> {
  int? _selectedIndex;

  final List<String> _phrases = [
    'Good morning',
    'Thank you very much',
    'Can I have some water, please?',
    'I need a moment',
    'Yes, I understand',
    'No, thank you',
    'Could you repeat that?',
    'I\'m doing well',
    'Nice to meet you',
    'See you later',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppleColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  AppleBackButton(label: 'Back'),
                  const Spacer(),
                ],
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    'Practice',
                    style: AppleTextStyles.largeTitle,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap a phrase to practice.',
                    style: AppleTextStyles.subheadline,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Phrase list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: _phrases.length,
                itemBuilder: (context, index) {
                  final isSelected = _selectedIndex == index;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _PhraseCard(
                      phrase: _phrases[index],
                      isSelected: isSelected,
                      onTap: () {
                        setState(() {
                          _selectedIndex = isSelected ? null : index;
                        });
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhraseCard extends StatelessWidget {
  final String phrase;
  final bool isSelected;
  final VoidCallback onTap;

  const _PhraseCard({
    required this.phrase,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? AppleColors.accentLight : AppleColors.secondaryBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppleColors.accent : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                phrase,
                style: AppleTextStyles.body.copyWith(
                  color: isSelected ? AppleColors.accent : AppleColors.label,
                ),
              ),
            ),
            const SizedBox(width: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isSelected 
                    ? AppleColors.accent 
                    : AppleColors.systemGray4,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSelected ? Icons.mic_rounded : Icons.play_arrow_rounded,
                size: 18,
                color: isSelected ? Colors.white : AppleColors.tertiaryLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
