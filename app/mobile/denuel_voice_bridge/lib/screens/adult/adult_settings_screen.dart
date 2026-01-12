import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../theme/adult_theme.dart';
import '../mode_selector/mode_selector_screen.dart';

/// Settings screen for Adult Mode
class AdultSettingsScreen extends StatelessWidget {
  const AdultSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsService>();
    final profile = settings.userProfile;

    return Scaffold(
      backgroundColor: AdultTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Settings', style: AdultTheme.headlineMedium),
              const SizedBox(height: 24),

              // Profile section
              _SectionHeader(title: 'Profile'),
              _SettingsTile(
                icon: Icons.person_outline,
                title: 'Name',
                subtitle: profile?.name ?? 'Not set',
                onTap: () => _showNameDialog(context, settings),
              ),
              _SettingsTile(
                icon: Icons.swap_horiz,
                title: 'Switch to Child Mode',
                subtitle: 'Change the app experience',
                onTap: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => const ModeSelectorScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              // Privacy section
              _SectionHeader(title: 'Privacy'),
              _SettingsToggle(
                icon: Icons.wifi_off_outlined,
                title: 'Offline Mode',
                subtitle: 'Process all data locally',
                value: settings.isOfflineMode,
                onChanged: (v) => settings.setOfflineMode(v),
              ),
              const SizedBox(height: 24),

              // Data section
              _SectionHeader(title: 'Data'),
              _SettingsTile(
                icon: Icons.download_outlined,
                title: 'Export Data',
                subtitle: 'Download your session history',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Export feature coming soon')),
                  );
                },
              ),
              _SettingsTile(
                icon: Icons.delete_outline,
                title: 'Clear All Data',
                subtitle: 'Delete all sessions and progress',
                titleColor: AdultTheme.error,
                onTap: () => _showClearDataDialog(context, settings),
              ),
              const SizedBox(height: 24),

              // About section
              _SectionHeader(title: 'About'),
              _SettingsTile(
                icon: Icons.info_outline,
                title: 'Version',
                subtitle: '1.0.0',
                showArrow: false,
              ),
              _SettingsTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Policy',
                onTap: () {},
              ),
              _SettingsTile(
                icon: Icons.description_outlined,
                title: 'Terms of Service',
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNameDialog(BuildContext context, AppSettingsService settings) {
    final controller = TextEditingController(text: settings.userProfile?.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter your name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                final profile = settings.userProfile;
                if (profile != null) {
                  settings.updateProfile(
                    profile.copyWith(name: controller.text),
                  );
                } else {
                  settings.createProfile(
                    name: controller.text,
                    mode: UserMode.adult,
                  );
                }
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showClearDataDialog(BuildContext context, AppSettingsService settings) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data?'),
        content: const Text(
          'This will permanently delete all your sessions, progress, and settings. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AdultTheme.error,
            ),
            onPressed: () {
              settings.clearAllData();
              context.read<SessionService>().clearAllSessions();
              Navigator.pop(context);
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => const ModeSelectorScreen(),
                ),
              );
            },
            child: const Text('Delete Everything'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: AdultTheme.labelMedium.copyWith(
          color: AdultTheme.textTertiary,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? titleColor;
  final VoidCallback? onTap;
  final bool showArrow;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.titleColor,
    this.onTap,
    this.showArrow = true,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AdultTheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Icon(icon, color: titleColor ?? AdultTheme.textSecondary, size: 22),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AdultTheme.titleMedium.copyWith(color: titleColor),
                    ),
                    if (subtitle != null)
                      Text(subtitle!, style: AdultTheme.bodySmall),
                  ],
                ),
              ),
              if (showArrow && onTap != null)
                Icon(
                  Icons.chevron_right,
                  color: AdultTheme.textTertiary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsToggle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsToggle({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AdultTheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: AdultTheme.textSecondary, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AdultTheme.titleMedium),
                if (subtitle != null)
                  Text(subtitle!, style: AdultTheme.bodySmall),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AdultTheme.primary,
          ),
        ],
      ),
    );
  }
}
