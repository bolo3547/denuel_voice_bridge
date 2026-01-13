import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/safe_button.dart';
import 'add_voice_flow/add_voice_intro_screen.dart';

/// MY VOICE PROFILES SCREEN
/// 
/// UX Purpose:
/// - Shows all saved voice profiles
/// - Clear privacy reassurance on every profile
/// - Easy to add new profiles
/// - No complex management - just select or add
/// 
/// Accessibility:
/// - Large touch targets for each profile
/// - Clear icons and labels
/// - Privacy notice always visible
class VoiceProfilesScreen extends StatefulWidget {
  const VoiceProfilesScreen({super.key});

  @override
  State<VoiceProfilesScreen> createState() => _VoiceProfilesScreenState();
}

class _VoiceProfilesScreenState extends State<VoiceProfilesScreen> {
  // Sample voice profiles (in real app, loaded from local storage)
  final List<VoiceProfile> _profiles = [
    VoiceProfile(
      id: '1',
      name: 'Emmanuel',
      subtitle: 'My Voice',
      isDefault: true,
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
    ),
    VoiceProfile(
      id: '2',
      name: 'Child Practice',
      subtitle: 'For helping my child',
      isDefault: false,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ];

  @override
  Widget build(BuildContext context) {
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
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'My Voice Profiles',
                      style: AppTextStyles.headline3,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Privacy notice - prominent
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.accentLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'All voice profiles are stored on this device only. Your voice never leaves your phone.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Profiles list
            Expanded(
              child: _profiles.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: _profiles.length,
                      itemBuilder: (context, index) {
                        return _ProfileCard(
                          profile: _profiles[index],
                          onTap: () => _onProfileSelected(_profiles[index]),
                        );
                      },
                    ),
            ),

            // Add new profile button
            Padding(
              padding: const EdgeInsets.all(24),
              child: SafeButton(
                icon: Icons.add_rounded,
                label: 'Add New Voice',
                onPressed: () => _navigateToAddVoice(),
                isPrimary: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_outline_rounded,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No voice profiles yet',
              style: AppTextStyles.headline3,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first voice profile to get started.',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _onProfileSelected(VoiceProfile profile) {
    // Show profile options
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
          children: [
            // Profile header
            Row(
              children: [
                _ProfileAvatar(name: profile.name, size: 56),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(profile.name, style: AppTextStyles.headline3),
                      Text(profile.subtitle, style: AppTextStyles.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Options
            ListTile(
              leading: Icon(Icons.check_circle_outline_rounded, 
                  color: AppColors.primary),
              title: Text('Set as default', style: AppTextStyles.bodyLarge),
              onTap: () {
                Navigator.pop(context);
                _setAsDefault(profile);
              },
            ),
            ListTile(
              leading: Icon(Icons.edit_outlined, color: AppColors.textSecondary),
              title: Text('Edit name', style: AppTextStyles.bodyLarge),
              onTap: () {
                Navigator.pop(context);
                _showEditNameDialog(profile);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded, 
                  color: AppColors.attention),
              title: Text('Remove profile', 
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.attention,
                  )),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(profile);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToAddVoice() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => 
            const AddVoiceIntroScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  void _setAsDefault(VoiceProfile profile) {
    setState(() {
      for (int i = 0; i < _profiles.length; i++) {
        _profiles[i] = VoiceProfile(
          id: _profiles[i].id,
          name: _profiles[i].name,
          subtitle: _profiles[i].subtitle,
          isDefault: _profiles[i].id == profile.id,
          createdAt: _profiles[i].createdAt,
        );
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${profile.name} set as default')),
    );
  }

  void _showEditNameDialog(VoiceProfile profile) {
    final controller = TextEditingController(text: profile.name);
    final subtitleController = TextEditingController(text: profile.subtitle);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Enter profile name',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: subtitleController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'e.g., My Voice',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() {
                  final index = _profiles.indexWhere((p) => p.id == profile.id);
                  if (index != -1) {
                    _profiles[index] = VoiceProfile(
                      id: profile.id,
                      name: controller.text,
                      subtitle: subtitleController.text.isEmpty 
                          ? profile.subtitle 
                          : subtitleController.text,
                      isDefault: profile.isDefault,
                      createdAt: profile.createdAt,
                    );
                  }
                });
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(VoiceProfile profile) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Profile?'),
        content: Text(
          'Are you sure you want to remove "${profile.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.attention,
            ),
            onPressed: () {
              setState(() {
                _profiles.removeWhere((p) => p.id == profile.id);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${profile.name} removed')),
              );
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

/// Voice profile data class
class VoiceProfile {
  final String id;
  final String name;
  final String subtitle;
  final bool isDefault;
  final DateTime createdAt;

  VoiceProfile({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.isDefault,
    required this.createdAt,
  });
}

/// Profile card widget
class _ProfileCard extends StatelessWidget {
  final VoiceProfile profile;
  final VoidCallback onTap;

  const _ProfileCard({
    required this.profile,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: profile.isDefault
                  ? Border.all(color: AppColors.primary.withOpacity(0.3), width: 2)
                  : null,
            ),
            child: Row(
              children: [
                _ProfileAvatar(name: profile.name),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            profile.name,
                            style: AppTextStyles.headline3.copyWith(fontSize: 18),
                          ),
                          if (profile.isDefault) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Default',
                                style: AppTextStyles.label.copyWith(
                                  fontSize: 11,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        profile.subtitle,
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Profile avatar with initial
class _ProfileAvatar extends StatelessWidget {
  final String name;
  final double size;

  const _ProfileAvatar({
    required this.name,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: AppTextStyles.headline2.copyWith(
            fontSize: size * 0.4,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

/// Simple back button
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
