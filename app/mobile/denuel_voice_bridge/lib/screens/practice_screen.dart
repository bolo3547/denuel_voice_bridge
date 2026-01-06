import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/safe_button.dart';
import '../widgets/mic_button.dart';

/// PRACTICE WITH NOTES SCREEN (Guided Confidence Mode)
/// 
/// UX Purpose:
/// - Allows user to read from prepared notes/scripts
/// - Notes remain visible during recording (no memory pressure)
/// - Pre-written affirmations build confidence
/// - No scoring or correction - just practice
/// - User can customize their own notes
/// 
/// Accessibility:
/// - Large, readable text for notes
/// - Notes stay on screen (no switching)
/// - Adjustable text size option
/// - High contrast card
class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  bool _isRecording = false;
  int _currentNoteIndex = 0;

  // Pre-written confidence-building scripts
  final List<PracticeNote> _notes = [
    PracticeNote(
      title: 'Introduction',
      content: 'My name is ___.\nI am speaking calmly.\nI deserve to be heard.',
    ),
    PracticeNote(
      title: 'Daily Affirmation',
      content: 'Today is a good day.\nI will take my time.\nMy voice matters.',
    ),
    PracticeNote(
      title: 'Ordering Food',
      content: 'I would like to order ___.\nThank you for your patience.\nI appreciate your help.',
    ),
    PracticeNote(
      title: 'Making a Call',
      content: 'Hello, this is ___.\nI am calling about ___.\nThank you for listening.',
    ),
    PracticeNote(
      title: 'Meeting Someone',
      content: 'Nice to meet you.\nMy name is ___.\nIt\'s great to be here.',
    ),
  ];

  void _toggleRecording() {
    setState(() {
      _isRecording = !_isRecording;
    });
  }

  void _nextNote() {
    setState(() {
      _currentNoteIndex = (_currentNoteIndex + 1) % _notes.length;
    });
  }

  void _previousNote() {
    setState(() {
      _currentNoteIndex = (_currentNoteIndex - 1 + _notes.length) % _notes.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentNote = _notes[_currentNoteIndex];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _BackButton(onPressed: () => Navigator.pop(context)),
                  const Spacer(),
                  Text(
                    'Practice with Notes',
                    style: AppTextStyles.headline3.copyWith(fontSize: 18),
                  ),
                  const Spacer(),
                  const SizedBox(width: 56), // Balance the back button
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Note card - stays visible during recording
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: _isRecording 
                          ? AppColors.listening.withOpacity(0.5)
                          : AppColors.primary.withOpacity(0.1),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.06),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Note title
                      Text(
                        currentNote.title,
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.primary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Note content - large, readable
                      Expanded(
                        child: Center(
                          child: Text(
                            currentNote.content,
                            style: AppTextStyles.headline2.copyWith(
                              height: 1.6,
                              fontSize: 22,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Note navigation
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: _previousNote,
                    icon: Icon(
                      Icons.chevron_left_rounded,
                      color: AppColors.textSecondary,
                      size: 32,
                    ),
                    tooltip: 'Previous note',
                  ),
                  const SizedBox(width: 16),
                  // Page indicator dots
                  Row(
                    children: List.generate(_notes.length, (index) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: index == _currentNoteIndex ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: index == _currentNoteIndex
                              ? AppColors.primary
                              : AppColors.primary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    onPressed: _nextNote,
                    icon: Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textSecondary,
                      size: 32,
                    ),
                    tooltip: 'Next note',
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Recording status
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                _isRecording 
                    ? 'Reading along with you…' 
                    : 'Press to start when ready',
                key: ValueKey(_isRecording),
                style: AppTextStyles.bodyMedium,
              ),
            ),

            const SizedBox(height: 24),

            // Mic button
            MicButton(
              isListening: _isRecording,
              onPressed: _toggleRecording,
            ),

            const SizedBox(height: 32),

            // Change notes button
            if (!_isRecording)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: TextButton.icon(
                  onPressed: () => _showNotesSelector(context),
                  icon: Icon(Icons.edit_note_rounded, color: AppColors.primary),
                  label: Text(
                    'Change or add notes',
                    style: AppTextStyles.buttonSecondary,
                  ),
                ),
              ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showNotesSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose a script',
              style: AppTextStyles.headline3,
            ),
            const SizedBox(height: 16),
            ...List.generate(_notes.length, (index) {
              final note = _notes[index];
              final isSelected = index == _currentNoteIndex;
              return ListTile(
                leading: Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  color: isSelected ? AppColors.primary : AppColors.textMuted,
                ),
                title: Text(
                  note.title,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                onTap: () {
                  setState(() => _currentNoteIndex = index);
                  Navigator.pop(context);
                },
              );
            }),
            const SizedBox(height: 16),
            // Add custom note option (placeholder)
            ListTile(
              leading: Icon(
                Icons.add_circle_outline_rounded,
                color: AppColors.primary,
              ),
              title: Text(
                'Write your own script',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.primary,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                // TODO: Open custom note editor
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple data class for practice notes
class PracticeNote {
  final String title;
  final String content;

  PracticeNote({required this.title, required this.content});
}

/// Simple back button widget
class _BackButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _BackButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceLight,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          child: Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
