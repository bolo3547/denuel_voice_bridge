import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing practice reminders and notifications
class NotificationService extends ChangeNotifier {
  static const _keyReminderEnabled = 'reminder_enabled';
  static const _keyReminderTime = 'reminder_time';
  static const _keyReminderDays = 'reminder_days';
  static const _keyMotivationalMessages = 'motivational_enabled';

  SharedPreferences? _prefs;
  bool _isReminderEnabled = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 9, minute: 0);
  List<int> _reminderDays = [1, 2, 3, 4, 5]; // Mon-Fri
  bool _motivationalMessagesEnabled = true;

  bool get isReminderEnabled => _isReminderEnabled;
  TimeOfDay get reminderTime => _reminderTime;
  List<int> get reminderDays => _reminderDays;
  bool get motivationalMessagesEnabled => _motivationalMessagesEnabled;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _loadSettings();
  }

  void _loadSettings() {
    _isReminderEnabled = _prefs?.getBool(_keyReminderEnabled) ?? false;
    
    final timeString = _prefs?.getString(_keyReminderTime);
    if (timeString != null) {
      final parts = timeString.split(':');
      _reminderTime = TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    }

    final daysString = _prefs?.getString(_keyReminderDays);
    if (daysString != null) {
      _reminderDays = daysString.split(',').map(int.parse).toList();
    }

    _motivationalMessagesEnabled = _prefs?.getBool(_keyMotivationalMessages) ?? true;
    notifyListeners();
  }

  Future<void> setReminderEnabled(bool enabled) async {
    _isReminderEnabled = enabled;
    await _prefs?.setBool(_keyReminderEnabled, enabled);
    
    if (enabled) {
      await _scheduleReminders();
    } else {
      await _cancelReminders();
    }
    
    notifyListeners();
  }

  Future<void> setReminderTime(TimeOfDay time) async {
    _reminderTime = time;
    await _prefs?.setString(_keyReminderTime, '${time.hour}:${time.minute}');
    
    if (_isReminderEnabled) {
      await _scheduleReminders();
    }
    
    notifyListeners();
  }

  Future<void> setReminderDays(List<int> days) async {
    _reminderDays = days;
    await _prefs?.setString(_keyReminderDays, days.join(','));
    
    if (_isReminderEnabled) {
      await _scheduleReminders();
    }
    
    notifyListeners();
  }

  Future<void> setMotivationalMessagesEnabled(bool enabled) async {
    _motivationalMessagesEnabled = enabled;
    await _prefs?.setBool(_keyMotivationalMessages, enabled);
    notifyListeners();
  }

  Future<void> _scheduleReminders() async {
    // In a real app, this would use flutter_local_notifications
    // to schedule actual system notifications
    debugPrint('Scheduling reminders for $_reminderTime on days $_reminderDays');
  }

  Future<void> _cancelReminders() async {
    debugPrint('Cancelling all reminders');
  }

  /// Get a motivational message for the user
  String getMotivationalMessage() {
    final messages = [
      "Every word you speak is progress. Let's practice! 💪",
      "Your voice matters. Time for today's practice! 🌟",
      "Small steps lead to big changes. Ready to practice? 🚀",
      "You're building confidence with every session! 🎯",
      "Today is another chance to grow. Let's go! ✨",
      "Your dedication is inspiring. Practice time! 🏆",
      "One more day, one more step forward! 💫",
      "Believe in your voice. Let's practice together! ❤️",
      "Progress isn't always visible, but it's happening! 🌱",
      "You've got this! Time for some practice. 💪",
    ];
    
    final dayOfYear = DateTime.now().difference(DateTime(DateTime.now().year)).inDays;
    return messages[dayOfYear % messages.length];
  }

  /// Get a streak encouragement message
  String getStreakMessage(int streak) {
    if (streak == 0) {
      return "Start your streak today! 🎯";
    } else if (streak == 1) {
      return "Day 1 complete! Keep going! 🌟";
    } else if (streak < 7) {
      return "$streak days strong! Almost a week! 💪";
    } else if (streak == 7) {
      return "One week streak! Amazing! 🎉";
    } else if (streak < 30) {
      return "$streak days! You're unstoppable! 🔥";
    } else if (streak == 30) {
      return "30 day streak! Incredible dedication! 🏆";
    } else {
      return "$streak days! You're a speech champion! 👑";
    }
  }

  /// Get day name
  String getDayName(int day) {
    switch (day) {
      case 1: return 'Mon';
      case 2: return 'Tue';
      case 3: return 'Wed';
      case 4: return 'Thu';
      case 5: return 'Fri';
      case 6: return 'Sat';
      case 7: return 'Sun';
      default: return '';
    }
  }
}

/// Widget for configuring practice reminders
class ReminderSettingsWidget extends StatelessWidget {
  final NotificationService notificationService;

  const ReminderSettingsWidget({
    super.key,
    required this.notificationService,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Enable toggle
        SwitchListTile(
          title: const Text('Daily Practice Reminders'),
          subtitle: const Text('Get reminded to practice'),
          value: notificationService.isReminderEnabled,
          onChanged: (value) => notificationService.setReminderEnabled(value),
        ),

        if (notificationService.isReminderEnabled) ...[
          // Time picker
          ListTile(
            title: const Text('Reminder Time'),
            subtitle: Text(notificationService.reminderTime.format(context)),
            trailing: const Icon(Icons.access_time),
            onTap: () async {
              final time = await showTimePicker(
                context: context,
                initialTime: notificationService.reminderTime,
              );
              if (time != null) {
                notificationService.setReminderTime(time);
              }
            },
          ),

          // Day selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Reminder Days'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: List.generate(7, (index) {
                    final day = index + 1;
                    final isSelected = notificationService.reminderDays.contains(day);
                    return FilterChip(
                      label: Text(notificationService.getDayName(day)),
                      selected: isSelected,
                      onSelected: (selected) {
                        final days = List<int>.from(notificationService.reminderDays);
                        if (selected) {
                          days.add(day);
                        } else {
                          days.remove(day);
                        }
                        days.sort();
                        notificationService.setReminderDays(days);
                      },
                    );
                  }),
                ),
              ],
            ),
          ),
        ],

        const Divider(),

        // Motivational messages toggle
        SwitchListTile(
          title: const Text('Motivational Messages'),
          subtitle: const Text('Show encouraging messages'),
          value: notificationService.motivationalMessagesEnabled,
          onChanged: (value) => notificationService.setMotivationalMessagesEnabled(value),
        ),
      ],
    );
  }
}
