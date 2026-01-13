import 'package:flutter/material.dart';
import '../../theme/adult_theme.dart';

/// Daily tips and educational content for speech improvement
class DailyTipsScreen extends StatefulWidget {
  const DailyTipsScreen({super.key});

  @override
  State<DailyTipsScreen> createState() => _DailyTipsScreenState();
}

class _DailyTipsScreenState extends State<DailyTipsScreen> {
  int _selectedCategory = 0;

  final List<TipCategory> _categories = [
    TipCategory(
      name: 'All Tips',
      icon: Icons.lightbulb_outline,
    ),
    TipCategory(
      name: 'Breathing',
      icon: Icons.air,
    ),
    TipCategory(
      name: 'Sounds',
      icon: Icons.record_voice_over,
    ),
    TipCategory(
      name: 'Confidence',
      icon: Icons.psychology,
    ),
    TipCategory(
      name: 'Daily Life',
      icon: Icons.today,
    ),
  ];

  final List<SpeechTip> _allTips = [
    // Breathing tips
    SpeechTip(
      title: 'Diaphragmatic Breathing',
      content: 'Place one hand on your chest and one on your belly. When you breathe in, your belly should rise more than your chest. This gives you better breath support for speaking.',
      category: 'Breathing',
      icon: '🌬️',
      isPremium: false,
    ),
    SpeechTip(
      title: 'Breath Before Speaking',
      content: 'Take a calm breath through your nose before starting to speak. This helps reduce nasal air escape and gives you the air you need for your sentence.',
      category: 'Breathing',
      icon: '💨',
      isPremium: false,
    ),
    SpeechTip(
      title: 'Pacing with Breath',
      content: 'Plan your breaths at natural pauses in sentences. Don\'t try to say too much on one breath - it\'s okay to pause!',
      category: 'Breathing',
      icon: '⏸️',
      isPremium: false,
    ),

    // Sound tips
    SpeechTip(
      title: 'Mirror Practice',
      content: 'Practice sounds in front of a mirror. Watch your lips for P, B, M sounds - they should close completely. This visual feedback helps you learn correct positions.',
      category: 'Sounds',
      icon: '🪞',
      isPremium: false,
    ),
    SpeechTip(
      title: 'Feel the Vibration',
      content: 'For sounds like B, D, G, Z, V - put your hand on your throat. You should feel vibration. If you don\'t, you might be substituting with P, T, K, S, F.',
      category: 'Sounds',
      icon: '✋',
      isPremium: false,
    ),
    SpeechTip(
      title: 'Slow Down for Clarity',
      content: 'Speaking slowly gives your articulators (tongue, lips, palate) more time to reach the correct position. Speed will come naturally with practice.',
      category: 'Sounds',
      icon: '🐢',
      isPremium: false,
    ),
    SpeechTip(
      title: 'Exaggerate to Learn',
      content: 'When practicing new sounds, exaggerate the movement. For K and G, really lift the back of your tongue. Once you can do it big, you can make it smaller.',
      category: 'Sounds',
      icon: '🎭',
      isPremium: false,
    ),

    // Confidence tips
    SpeechTip(
      title: 'Prepare Key Phrases',
      content: 'Before important conversations, practice key words and phrases you\'ll need. Familiarity builds confidence and reduces anxiety.',
      category: 'Confidence',
      icon: '📝',
      isPremium: false,
    ),
    SpeechTip(
      title: 'It\'s Okay to Repeat',
      content: 'If someone doesn\'t understand you, it\'s completely okay. Try saying it differently, slower, or rephrase. Most people appreciate the effort.',
      category: 'Confidence',
      icon: '🔄',
      isPremium: false,
    ),
    SpeechTip(
      title: 'Focus on Connection',
      content: 'Remember that communication is about connecting with others, not being perfect. Your message matters more than perfect pronunciation.',
      category: 'Confidence',
      icon: '❤️',
      isPremium: false,
    ),
    SpeechTip(
      title: 'Celebrate Small Wins',
      content: 'Did you successfully order coffee? Make a phone call? Say a difficult word? Celebrate these moments - they build confidence over time.',
      category: 'Confidence',
      icon: '🎉',
      isPremium: false,
    ),

    // Daily life tips
    SpeechTip(
      title: 'Phone Call Strategy',
      content: 'For phone calls: find a quiet space, have notes ready, speak slightly slower than normal, and don\'t be afraid to ask them to repeat if needed.',
      category: 'Daily Life',
      icon: '📱',
      isPremium: false,
    ),
    SpeechTip(
      title: 'Restaurant Ordering',
      content: 'Point to menu items while saying them. If the name is hard to pronounce, describe it: "the chicken dish" or "number 5". Waiters appreciate clarity.',
      category: 'Daily Life',
      icon: '🍽️',
      isPremium: false,
    ),
    SpeechTip(
      title: 'Meeting Introductions',
      content: 'Practice your name and title often. Consider having a simple, memorable phrase ready. Speaking first in introductions can feel easier than waiting.',
      category: 'Daily Life',
      icon: '🤝',
      isPremium: false,
    ),
    SpeechTip(
      title: 'Noisy Environment Strategy',
      content: 'In loud places, get closer to who you\'re talking to, face them directly, and use gestures to support your speech. It\'s okay to suggest moving somewhere quieter.',
      category: 'Daily Life',
      icon: '🔊',
      isPremium: false,
    ),
  ];

  List<SpeechTip> get _filteredTips {
    if (_selectedCategory == 0) return _allTips;
    return _allTips.where((tip) => tip.category == _categories[_selectedCategory].name).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdultTheme.background,
      appBar: AppBar(
        title: const Text('Speech Tips & Techniques'),
        backgroundColor: AdultTheme.background,
      ),
      body: Column(
        children: [
          // Today's featured tip
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0D9488), Color(0xFF14B8A6)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AdultTheme.primary.withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '✨ Today\'s Tip',
                        style: AdultTheme.labelMedium.copyWith(color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Progress Over Perfection',
                  style: AdultTheme.headlineSmall.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  'Every time you practice, you\'re building new neural pathways. Even when it feels hard, your brain is learning. Trust the process.',
                  style: AdultTheme.bodyMedium.copyWith(color: Colors.white.withOpacity(0.9)),
                ),
              ],
            ),
          ),

          // Category tabs
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = index == _selectedCategory;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = index),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isSelected ? AdultTheme.primary : AdultTheme.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isSelected ? AdultTheme.primary : AdultTheme.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          category.icon,
                          size: 18,
                          color: isSelected ? Colors.white : AdultTheme.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          category.name,
                          style: AdultTheme.labelMedium.copyWith(
                            color: isSelected ? Colors.white : AdultTheme.textSecondary,
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

          // Tips list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filteredTips.length,
              itemBuilder: (context, index) {
                final tip = _filteredTips[index];
                return _TipCard(tip: tip);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  final SpeechTip tip;

  const _TipCard({required this.tip});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AdultTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdultTheme.border),
      ),
      child: ExpansionTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AdultTheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(tip.icon, style: const TextStyle(fontSize: 24)),
          ),
        ),
        title: Text(tip.title, style: AdultTheme.titleMedium),
        subtitle: Text(tip.category, style: AdultTheme.bodySmall),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                const SizedBox(height: 8),
                Text(tip.content, style: AdultTheme.bodyMedium),
                const SizedBox(height: 12),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.bookmark_border, size: 18),
                      label: const Text('Save'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.share, size: 18),
                      label: const Text('Share'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TipCategory {
  final String name;
  final IconData icon;

  TipCategory({required this.name, required this.icon});
}

class SpeechTip {
  final String title;
  final String content;
  final String category;
  final String icon;
  final bool isPremium;

  SpeechTip({
    required this.title,
    required this.content,
    required this.category,
    required this.icon,
    this.isPremium = false,
  });
}
