import 'package:flutter/material.dart';
import 'dart:html' as html;
import '../theme.dart';
import '../services/voice_bridge_service.dart';

/// QuickPhrasesScreen - One-tap access to common phrases
/// 
/// Categories:
/// - Favorites (user's most used)
/// - Emergency phrases
/// - Greetings
/// - Restaurant
/// - Shopping
/// - Doctor/Medical
/// - Work/Professional

class QuickPhrasesScreen extends StatefulWidget {
  const QuickPhrasesScreen({super.key});

  @override
  State<QuickPhrasesScreen> createState() => _QuickPhrasesScreenState();
}

class _QuickPhrasesScreenState extends State<QuickPhrasesScreen> {
  String _selectedCategory = 'favorites';
  String? _playingPhrase;
  html.AudioElement? _audioPlayer;
  bool _isProcessing = false;

  // Phrase categories
  final Map<String, List<PhraseItem>> _categories = {
    'favorites': [
      PhraseItem('Hello, my name is Denuel', Icons.person),
      PhraseItem('Nice to meet you', Icons.handshake),
      PhraseItem('Thank you very much', Icons.favorite),
      PhraseItem('Could you please repeat that?', Icons.replay),
      PhraseItem('I need a moment to think', Icons.timer),
    ],
    'emergency': [
      PhraseItem('I need help', Icons.emergency, isUrgent: true),
      PhraseItem('Please call someone for me', Icons.phone, isUrgent: true),
      PhraseItem('I\'m not feeling well', Icons.healing, isUrgent: true),
      PhraseItem('I need to sit down', Icons.chair, isUrgent: true),
      PhraseItem('Where is the nearest hospital?', Icons.local_hospital, isUrgent: true),
    ],
    'greetings': [
      PhraseItem('Good morning', Icons.wb_sunny),
      PhraseItem('Good afternoon', Icons.wb_cloudy),
      PhraseItem('Good evening', Icons.nights_stay),
      PhraseItem('How are you today?', Icons.emoji_emotions),
      PhraseItem('See you later', Icons.waving_hand),
      PhraseItem('Have a nice day', Icons.sentiment_satisfied),
      PhraseItem('Goodbye', Icons.door_front_door),
    ],
    'restaurant': [
      PhraseItem('I would like to order please', Icons.restaurant_menu),
      PhraseItem('Could I see the menu?', Icons.menu_book),
      PhraseItem('Water please', Icons.water_drop),
      PhraseItem('The check please', Icons.receipt_long),
      PhraseItem('Is this gluten free?', Icons.no_food),
      PhraseItem('I have a food allergy', Icons.warning_amber),
      PhraseItem('This is delicious', Icons.thumb_up),
    ],
    'shopping': [
      PhraseItem('How much does this cost?', Icons.attach_money),
      PhraseItem('Do you have this in a different size?', Icons.straighten),
      PhraseItem('Where can I find...', Icons.search),
      PhraseItem('I\'m just looking, thank you', Icons.visibility),
      PhraseItem('Can I pay by card?', Icons.credit_card),
      PhraseItem('Do you have a bag?', Icons.shopping_bag),
    ],
    'medical': [
      PhraseItem('I have an appointment', Icons.calendar_today),
      PhraseItem('I need to see a doctor', Icons.medical_services),
      PhraseItem('I take medication for...', Icons.medication),
      PhraseItem('I\'m allergic to...', Icons.dangerous),
      PhraseItem('Where does it hurt?', Icons.accessibility),
      PhraseItem('Can you explain that again?', Icons.help_outline),
    ],
    'work': [
      PhraseItem('Good morning everyone', Icons.groups),
      PhraseItem('I have a question', Icons.help),
      PhraseItem('Could you send me an email about that?', Icons.email),
      PhraseItem('Let me check and get back to you', Icons.fact_check),
      PhraseItem('I agree with that point', Icons.thumb_up),
      PhraseItem('Can we schedule a meeting?', Icons.event),
    ],
  };

  final Map<String, CategoryInfo> _categoryInfo = {
    'favorites': CategoryInfo('Favorites', Icons.star_rounded, AppColors.warning),
    'emergency': CategoryInfo('Emergency', Icons.emergency, AppColors.error),
    'greetings': CategoryInfo('Greetings', Icons.waving_hand, AppColors.primary),
    'restaurant': CategoryInfo('Restaurant', Icons.restaurant, Colors.orange),
    'shopping': CategoryInfo('Shopping', Icons.shopping_cart, Colors.purple),
    'medical': CategoryInfo('Medical', Icons.local_hospital, Colors.teal),
    'work': CategoryInfo('Work', Icons.work, Colors.indigo),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Phrases',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap any phrase to speak it instantly',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            // Category chips
            SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _categoryInfo.length,
                itemBuilder: (context, index) {
                  final key = _categoryInfo.keys.elementAt(index);
                  final info = _categoryInfo[key]!;
                  final isSelected = _selectedCategory == key;
                  
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _CategoryChip(
                      label: info.name,
                      icon: info.icon,
                      color: info.color,
                      isSelected: isSelected,
                      onTap: () => setState(() => _selectedCategory = key),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Phrases list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _categories[_selectedCategory]?.length ?? 0,
                itemBuilder: (context, index) {
                  final phrase = _categories[_selectedCategory]![index];
                  final isPlaying = _playingPhrase == phrase.text;
                  
                  return _PhraseCard(
                    phrase: phrase,
                    isPlaying: isPlaying,
                    isProcessing: _isProcessing && isPlaying,
                    categoryColor: _categoryInfo[_selectedCategory]!.color,
                    onTap: () => _speakPhrase(phrase.text),
                    onLongPress: () => _showPhraseOptions(phrase),
                  );
                },
              ),
            ),

            // Add custom phrase button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _showAddPhraseDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Custom Phrase'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _speakPhrase(String text) async {
    setState(() {
      _playingPhrase = text;
      _isProcessing = true;
    });

    try {
      final result = await VoiceBridgeService.processText(text);
      
      if (result['success'] == true && result['audio_base64'] != null) {
        _audioPlayer?.pause();
        final dataUrl = 'data:audio/wav;base64,${result['audio_base64']}';
        _audioPlayer = html.AudioElement(dataUrl);
        
        _audioPlayer!.onEnded.listen((_) {
          if (mounted) {
            setState(() {
              _playingPhrase = null;
              _isProcessing = false;
            });
          }
        });
        
        _audioPlayer!.play();
        setState(() => _isProcessing = false);
      } else {
        setState(() {
          _playingPhrase = null;
          _isProcessing = false;
        });
        _showError('Could not generate speech. Please check the backend server.');
      }
    } catch (e) {
      print('Error speaking phrase: $e');
      setState(() {
        _playingPhrase = null;
        _isProcessing = false;
      });
      _showError('Connection error. Make sure the backend is running.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showPhraseOptions(PhraseItem phrase) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
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
            Text(
              phrase.text,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.star_outline),
              title: const Text('Add to Favorites'),
              onTap: () {
                Navigator.pop(context);
                _addToFavorites(phrase);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit Phrase'),
              onTap: () {
                Navigator.pop(context);
                _editPhrase(phrase);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: AppColors.error),
              title: Text('Delete', style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.pop(context);
                _deletePhrase(phrase);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _addToFavorites(PhraseItem phrase) {
    // Add to favorites category
    setState(() {
      if (!_categories['favorites']!.any((p) => p.text == phrase.text)) {
        _categories['favorites']!.insert(0, phrase);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Added to favorites!'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _editPhrase(PhraseItem phrase) {
    // TODO: Implement edit dialog
  }

  void _deletePhrase(PhraseItem phrase) {
    // TODO: Implement delete confirmation
  }

  void _showAddPhraseDialog() {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add Custom Phrase'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Enter your phrase...',
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() {
                  _categories['favorites']!.add(
                    PhraseItem(controller.text.trim(), Icons.chat_bubble),
                  );
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

// Data classes
class PhraseItem {
  final String text;
  final IconData icon;
  final bool isUrgent;

  PhraseItem(this.text, this.icon, {this.isUrgent = false});
}

class CategoryInfo {
  final String name;
  final IconData icon;
  final Color color;

  CategoryInfo(this.name, this.icon, this.color);
}

// Widgets
class _CategoryChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : AppColors.surface,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isSelected ? color : AppColors.surfaceVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: isSelected ? color : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhraseCard extends StatelessWidget {
  final PhraseItem phrase;
  final bool isPlaying;
  final bool isProcessing;
  final Color categoryColor;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _PhraseCard({
    required this.phrase,
    required this.isPlaying,
    required this.isProcessing,
    required this.categoryColor,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isPlaying 
                  ? categoryColor.withOpacity(0.15)
                  : phrase.isUrgent 
                      ? AppColors.error.withOpacity(0.1)
                      : AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isPlaying 
                    ? categoryColor
                    : phrase.isUrgent 
                        ? AppColors.error.withOpacity(0.3)
                        : AppColors.surfaceVariant,
                width: isPlaying ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: phrase.isUrgent 
                        ? AppColors.error.withOpacity(0.15)
                        : categoryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    phrase.icon,
                    color: phrase.isUrgent ? AppColors.error : categoryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    phrase.text,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: phrase.isUrgent ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (isProcessing)
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: categoryColor,
                    ),
                  )
                else if (isPlaying)
                  Icon(Icons.volume_up, color: categoryColor)
                else
                  Icon(
                    Icons.play_circle_outline,
                    color: AppColors.textSecondary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
