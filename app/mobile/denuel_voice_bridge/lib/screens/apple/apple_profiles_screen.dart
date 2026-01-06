import 'package:flutter/material.dart';
import '../../theme/apple_colors.dart';
import '../../theme/apple_text_styles.dart';
import '../../widgets/apple_buttons.dart';
import '../../widgets/apple_list.dart';
import 'apple_add_voice_intro.dart';

/// VOICE PROFILES - Apple Settings Style
/// 
/// UX Philosophy:
/// - Clear list of saved voices
/// - Each profile feels personal, not clinical
/// - Easy to add new, manage existing
/// - Visual warmth through avatars
/// 
/// Apple Inspiration:
/// - iOS Settings > General > Accessibility
/// - iOS Contacts app
/// - Apple Watch faces picker
class AppleProfilesScreen extends StatelessWidget {
  const AppleProfilesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profiles = [
      _VoiceProfile(
        name: 'Dad\'s Voice',
        samplesCount: 12,
        initial: 'D',
        isActive: true,
      ),
      _VoiceProfile(
        name: 'Natural',
        samplesCount: 8,
        initial: 'N',
        isActive: false,
      ),
    ];

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
                    'Voice Profiles',
                    style: AppleTextStyles.largeTitle,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your saved voices.',
                    style: AppleTextStyles.subheadline,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Profiles list
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  // My Profiles section
                  AppleGroupedSection(
                    header: 'MY PROFILES',
                    children: profiles.map((profile) {
                      return AppleListRow(
                        leading: AppleAvatar(
                          initial: profile.initial,
                          isActive: profile.isActive,
                        ),
                        title: profile.name,
                        subtitle: '${profile.samplesCount} voice samples',
                        trailing: profile.isActive
                            ? Icon(
                                Icons.check_circle_rounded,
                                color: AppleColors.accent,
                                size: 22,
                              )
                            : Icon(
                                Icons.circle_outlined,
                                color: AppleColors.tertiaryLabel,
                                size: 22,
                              ),
                        onTap: () => _showProfileSheet(context, profile),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),

                  // Add new profile button
                  GestureDetector(
                    onTap: () => _startAddVoice(context),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppleColors.secondaryBackground,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppleColors.accentLight,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.add_rounded,
                              color: AppleColors.accent,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Add a Voice',
                                  style: AppleTextStyles.body.copyWith(
                                    color: AppleColors.accent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Create a new voice profile',
                                  style: AppleTextStyles.footnote,
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: AppleColors.tertiaryLabel,
                            size: 22,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Footer explanation
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'Voice profiles are stored only on this device. '
                      'You can create profiles from your own recordings or '
                      'from recordings of loved ones.',
                      style: AppleTextStyles.footnote,
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showProfileSheet(BuildContext context, _VoiceProfile profile) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppleColors.secondaryBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: AppleColors.systemGray4,
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),

            const SizedBox(height: 24),

            // Profile avatar
            AppleAvatar(
              initial: profile.initial,
              isActive: profile.isActive,
              size: 64,
            ),

            const SizedBox(height: 16),

            Text(
              profile.name,
              style: AppleTextStyles.title2,
            ),
            const SizedBox(height: 4),
            Text(
              '${profile.samplesCount} voice samples',
              style: AppleTextStyles.subheadline,
            ),

            const SizedBox(height: 24),

            // Action buttons
            ApplePillButton(
              label: profile.isActive ? 'Currently Active' : 'Make Active',
              onPressed: profile.isActive ? null : () => Navigator.pop(context),
              isPrimary: !profile.isActive,
            ),

            const SizedBox(height: 12),

            AppleTextButton(
              label: 'Delete Profile',
              onPressed: () => Navigator.pop(context),
              color: AppleColors.destructive,
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _startAddVoice(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const AppleAddVoiceIntro(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }
}

class _VoiceProfile {
  final String name;
  final int samplesCount;
  final String initial;
  final bool isActive;

  _VoiceProfile({
    required this.name,
    required this.samplesCount,
    required this.initial,
    required this.isActive,
  });
}
