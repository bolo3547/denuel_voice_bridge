import 'package:flutter/material.dart';
import '../theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Settings state
  bool _notificationsEnabled = true;
  bool _autoSaveRecordings = false;
  String _speechRate = 'Normal';
  String _voiceQuality = 'High';

  @override
  Widget build(BuildContext context) {
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
                    'Settings',
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Customize your experience',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          ),
          
          // Account section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _SettingsSection(
                title: 'ACCOUNT',
                children: [
                  _SettingsTile(
                    icon: Icons.person_outline_rounded,
                    title: 'Profile',
                    subtitle: 'Denuel',
                    onTap: () => _showProfileDialog(context),
                  ),
                  _SettingsTile(
                    icon: Icons.notifications_outlined,
                    title: 'Notifications',
                    trailing: Switch(
                      value: _notificationsEnabled,
                      onChanged: (v) {
                        setState(() => _notificationsEnabled = v);
                        _showSnackBar(context, 'Notifications ${v ? 'enabled' : 'disabled'}');
                      },
                      activeColor: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          
          // Voice section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _SettingsSection(
                title: 'VOICE',
                children: [
                  _SettingsTile(
                    icon: Icons.speed_rounded,
                    title: 'Speech Rate',
                    subtitle: _speechRate,
                    onTap: () => _showSpeechRateDialog(context),
                  ),
                  _SettingsTile(
                    icon: Icons.tune_rounded,
                    title: 'Voice Quality',
                    subtitle: _voiceQuality,
                    onTap: () => _showVoiceQualityDialog(context),
                  ),
                  _SettingsTile(
                    icon: Icons.save_outlined,
                    title: 'Auto-save Recordings',
                    trailing: Switch(
                      value: _autoSaveRecordings,
                      onChanged: (v) {
                        setState(() => _autoSaveRecordings = v);
                        _showSnackBar(context, 'Auto-save ${v ? 'enabled' : 'disabled'}');
                      },
                      activeColor: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          
          // Privacy section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _SettingsSection(
                title: 'PRIVACY & DATA',
                children: [
                  _SettingsTile(
                    icon: Icons.shield_outlined,
                    title: 'Privacy Policy',
                    onTap: () => _showPrivacyPolicy(context),
                  ),
                  _SettingsTile(
                    icon: Icons.delete_outline_rounded,
                    title: 'Clear All Data',
                    titleColor: AppColors.error,
                    onTap: () => _showClearDataDialog(context),
                  ),
                ],
              ),
            ),
          ),
          
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          
          // About section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _SettingsSection(
                title: 'ABOUT',
                children: [
                  const _SettingsTile(
                    icon: Icons.info_outline_rounded,
                    title: 'Version',
                    subtitle: '1.0.0',
                  ),
                  _SettingsTile(
                    icon: Icons.help_outline_rounded,
                    title: 'Help & Support',
                    onTap: () => _showHelpDialog(context),
                  ),
                  _SettingsTile(
                    icon: Icons.star_outline_rounded,
                    title: 'Rate App',
                    onTap: () => _showSnackBar(context, 'Thank you for your support! ⭐'),
                  ),
                ],
              ),
            ),
          ),
          
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  void _showSnackBar(BuildContext context, String message) {
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

  void _showProfileDialog(BuildContext context) {
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
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.person_rounded, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 20),
            TextField(
              decoration: InputDecoration(
                labelText: 'Name',
                hintText: 'Enter your name',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
              ),
              controller: TextEditingController(text: 'Denuel'),
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
              Navigator.pop(context);
              _showSnackBar(context, 'Profile updated');
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

  void _showSpeechRateDialog(BuildContext context) {
    final options = ['Slow', 'Normal', 'Fast', 'Very Fast'];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Speech Rate'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((option) => RadioListTile<String>(
            title: Text(option),
            value: option,
            groupValue: _speechRate,
            activeColor: AppColors.primary,
            onChanged: (value) {
              setState(() => _speechRate = value!);
              Navigator.pop(context);
              _showSnackBar(context, 'Speech rate set to $value');
            },
          )).toList(),
        ),
      ),
    );
  }

  void _showVoiceQualityDialog(BuildContext context) {
    final options = ['Low', 'Medium', 'High', 'Ultra'];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Voice Quality'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((option) => RadioListTile<String>(
            title: Text(option),
            value: option,
            groupValue: _voiceQuality,
            activeColor: AppColors.primary,
            onChanged: (value) {
              setState(() => _voiceQuality = value!);
              Navigator.pop(context);
              _showSnackBar(context, 'Voice quality set to $value');
            },
          )).toList(),
        ),
      ),
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Privacy Policy', style: Theme.of(context).textTheme.displaySmall),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Text(
                    '''Voice Bridge Privacy Policy

1. Data Collection
We collect voice samples only with your explicit consent. All voice data is stored locally on your device by default.

2. Voice Processing
Your voice samples are processed using on-device AI when possible. When cloud processing is required, data is encrypted end-to-end.

3. Data Storage
Voice profiles are stored securely on your device. You maintain full control over your data and can delete it at any time.

4. Third-Party Sharing
We never sell or share your voice data with third parties for advertising or other commercial purposes.

5. Security
We use industry-standard encryption to protect your data both at rest and in transit.

6. Your Rights
You have the right to access, modify, and delete all your personal data at any time through the app settings.

For questions, contact: privacy@voicebridge.app''',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showClearDataDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: AppColors.error),
            const SizedBox(width: 8),
            const Text('Clear All Data'),
          ],
        ),
        content: const Text(
          'This will permanently delete all your voice profiles, recordings, and settings. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _showSnackBar(context, 'All data cleared');
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Clear Data'),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Help & Support'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HelpItem(icon: Icons.email_outlined, title: 'Email Support', subtitle: 'support@voicebridge.app'),
            const SizedBox(height: 12),
            _HelpItem(icon: Icons.book_outlined, title: 'User Guide', subtitle: 'Learn how to use Voice Bridge'),
            const SizedBox(height: 12),
            _HelpItem(icon: Icons.chat_outlined, title: 'FAQ', subtitle: 'Frequently asked questions'),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _HelpItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _HelpItem({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textTertiary,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.surfaceVariant),
          ),
          child: Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1)
                  Divider(
                    height: 1,
                    indent: 56,
                    color: AppColors.surfaceVariant,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? titleColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 20,
                color: titleColor ?? AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: titleColor ?? AppColors.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (onTap != null)
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
