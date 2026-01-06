import 'package:flutter/material.dart';
import '../theme.dart';

class VoiceProfile {
  final String id;
  final String name;
  final int samples;
  final Gradient gradient;
  bool isActive;

  VoiceProfile({
    required this.id,
    required this.name,
    required this.samples,
    required this.gradient,
    this.isActive = false,
  });
}

class ProfilesScreen extends StatefulWidget {
  const ProfilesScreen({super.key});

  @override
  State<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends State<ProfilesScreen> {
  final List<VoiceProfile> _profiles = [
    VoiceProfile(
      id: '1',
      name: 'My Voice',
      samples: 12,
      gradient: AppColors.primaryGradient,
      isActive: true,
    ),
    VoiceProfile(
      id: '2',
      name: "Dad's Voice",
      samples: 8,
      gradient: const LinearGradient(
        colors: [Color(0xFF22C55E), Color(0xFF10B981)],
      ),
    ),
    VoiceProfile(
      id: '3',
      name: 'Natural',
      samples: 5,
      gradient: const LinearGradient(
        colors: [Color(0xFFF59E0B), Color(0xFFF97316)],
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final activeProfile = _profiles.firstWhere((p) => p.isActive);
    final otherProfiles = _profiles.where((p) => !p.isActive).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Voice Profiles',
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manage your saved voices',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          ),
          
          // Active profile
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ACTIVE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTertiary,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ProfileCard(
                    profile: activeProfile,
                    onTap: () => _showProfileOptions(context, activeProfile),
                    onMoreTap: () => _showProfileOptions(context, activeProfile),
                  ),
                ],
              ),
            ),
          ),
          
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          
          // Other profiles
          if (otherProfiles.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'OTHER PROFILES',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textTertiary,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...otherProfiles.map((profile) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ProfileCard(
                        profile: profile,
                        onTap: () => _setActiveProfile(profile),
                        onMoreTap: () => _showProfileOptions(context, profile),
                      ),
                    )),
                  ],
                ),
              ),
            ),
          
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          
          // Add new profile button
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _AddProfileCard(onTap: () => _showAddProfileDialog(context)),
            ),
          ),
          
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  void _setActiveProfile(VoiceProfile profile) {
    setState(() {
      for (var p in _profiles) {
        p.isActive = false;
      }
      profile.isActive = true;
    });
    _showSnackBar('Switched to "${profile.name}"');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: AppColors.textPrimary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showProfileOptions(BuildContext context, VoiceProfile profile) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            
            // Profile header
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: profile.gradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      profile.name[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.name, style: Theme.of(context).textTheme.titleMedium),
                    Text('${profile.samples} voice samples', 
                      style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Options
            if (!profile.isActive)
              _OptionTile(
                icon: Icons.check_circle_outline_rounded,
                title: 'Set as Active',
                onTap: () {
                  Navigator.pop(context);
                  _setActiveProfile(profile);
                },
              ),
            
            _OptionTile(
              icon: Icons.edit_outlined,
              title: 'Edit Profile',
              onTap: () {
                Navigator.pop(context);
                _showEditProfileDialog(context, profile);
              },
            ),
            
            _OptionTile(
              icon: Icons.mic_none_rounded,
              title: 'Add Voice Samples',
              onTap: () {
                Navigator.pop(context);
                _showSnackBar('Recording new voice samples...');
              },
            ),
            
            _OptionTile(
              icon: Icons.play_circle_outline_rounded,
              title: 'Preview Voice',
              onTap: () {
                Navigator.pop(context);
                _showSnackBar('Playing voice preview...');
              },
            ),
            
            if (_profiles.length > 1)
              _OptionTile(
                icon: Icons.delete_outline_rounded,
                title: 'Delete Profile',
                color: AppColors.error,
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmation(context, profile);
                },
              ),
            
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, VoiceProfile profile) {
    final controller = TextEditingController(text: profile.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: profile.gradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  profile.name[0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Profile Name',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() {
                  final index = _profiles.indexWhere((p) => p.id == profile.id);
                  if (index != -1) {
                    _profiles[index] = VoiceProfile(
                      id: profile.id,
                      name: controller.text,
                      samples: profile.samples,
                      gradient: profile.gradient,
                      isActive: profile.isActive,
                    );
                  }
                });
                Navigator.pop(context);
                _showSnackBar('Profile updated');
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, VoiceProfile profile) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: AppColors.error),
            const SizedBox(width: 8),
            const Text('Delete Profile'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${profile.name}"? This will also delete all ${profile.samples} voice samples. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                _profiles.removeWhere((p) => p.id == profile.id);
                if (profile.isActive && _profiles.isNotEmpty) {
                  _profiles.first.isActive = true;
                }
              });
              Navigator.pop(context);
              _showSnackBar('Profile deleted');
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddProfileDialog(BuildContext context) {
    final controller = TextEditingController();
    final gradients = [
      AppColors.primaryGradient,
      const LinearGradient(colors: [Color(0xFF22C55E), Color(0xFF10B981)]),
      const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFF97316)]),
      const LinearGradient(colors: [Color(0xFFEC4899), Color(0xFFF43F5E)]),
      const LinearGradient(colors: [Color(0xFF06B6D4), Color(0xFF0EA5E9)]),
      const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFFA855F7)]),
    ];
    int selectedGradient = 0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Create New Profile'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: gradients[selectedGradient],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.person_add_rounded, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 16),
              
              // Color picker
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(gradients.length, (index) => 
                  GestureDetector(
                    onTap: () => setDialogState(() => selectedGradient = index),
                    child: Container(
                      width: 32,
                      height: 32,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        gradient: gradients[index],
                        borderRadius: BorderRadius.circular(8),
                        border: selectedGradient == index 
                            ? Border.all(color: Colors.white, width: 3)
                            : null,
                        boxShadow: selectedGradient == index
                            ? [BoxShadow(color: Colors.black26, blurRadius: 4)]
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'Profile Name',
                  hintText: 'e.g., Work Voice, Casual',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  setState(() {
                    _profiles.add(VoiceProfile(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: controller.text,
                      samples: 0,
                      gradient: gradients[selectedGradient],
                    ));
                  });
                  Navigator.pop(context);
                  _showSnackBar('Profile "${controller.text}" created');
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final VoiceProfile profile;
  final VoidCallback onTap;
  final VoidCallback onMoreTap;

  const _ProfileCard({
    required this.profile,
    required this.onTap,
    required this.onMoreTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: profile.isActive 
              ? Border.all(color: AppColors.primary, width: 2)
              : Border.all(color: AppColors.surfaceVariant),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: profile.gradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  profile.name[0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          profile.name,
                          style: Theme.of(context).textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (profile.isActive) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Active',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.success,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${profile.samples} voice samples',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            
            // Actions
            IconButton(
              icon: Icon(
                Icons.more_vert_rounded,
                color: AppColors.textTertiary,
              ),
              onPressed: onMoreTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _AddProfileCard extends StatelessWidget {
  final VoidCallback onTap;

  const _AddProfileCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.surfaceVariant,
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.add_rounded,
                color: AppColors.primary,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create New Profile',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Add a new voice to your collection',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? color;

  const _OptionTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppColors.textPrimary),
      title: Text(title, style: TextStyle(color: color)),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
