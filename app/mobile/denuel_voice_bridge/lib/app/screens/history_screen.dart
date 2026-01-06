import 'package:flutter/material.dart';
import 'dart:html' as html;
import '../theme.dart';
import '../services/voice_bridge_service.dart';

/// HistoryScreen - Review and replay past conversations
/// 
/// Features:
/// - List of past phrases with timestamps
/// - Replay audio
/// - Delete items
/// - Search/filter

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final List<HistoryItem> _history = [
    // Sample data - would be loaded from storage in real app
    HistoryItem(
      originalText: 'Hello how are you today',
      normalizedText: 'Hello, how are you today?',
      timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      audioBase64: null,
    ),
    HistoryItem(
      originalText: 'I wanna go to da store',
      normalizedText: 'I want to go to the store',
      timestamp: DateTime.now().subtract(const Duration(hours: 3)),
      audioBase64: null,
    ),
    HistoryItem(
      originalText: 'Thank you very much',
      normalizedText: 'Thank you very much',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      audioBase64: null,
    ),
  ];

  String? _playingId;
  html.AudioElement? _audioPlayer;

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
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'History',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_history.length} conversations',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_history.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: _showClearAllDialog,
                      tooltip: 'Clear all',
                    ),
                ],
              ),
            ),

            // History list
            Expanded(
              child: _history.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _history.length,
                      itemBuilder: (context, index) {
                        final item = _history[index];
                        return _HistoryCard(
                          item: item,
                          isPlaying: _playingId == item.id,
                          onPlay: () => _replayItem(item),
                          onDelete: () => _deleteItem(item),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.history,
              size: 48,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No history yet',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Your conversations will appear here',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _replayItem(HistoryItem item) async {
    setState(() => _playingId = item.id);

    try {
      // Generate audio from normalized text
      final result = await VoiceBridgeService.processText(item.normalizedText);
      
      if (!mounted) return;

      if (result['success'] == true && result['audio_base64'] != null) {
        _audioPlayer?.pause();
        final dataUrl = 'data:audio/wav;base64,${result['audio_base64']}';
        _audioPlayer = html.AudioElement(dataUrl);
        
        _audioPlayer!.onEnded.listen((_) {
          if (mounted) {
            setState(() => _playingId = null);
          }
        });
        
        _audioPlayer!.play();
      } else {
        setState(() => _playingId = null);
        _showError('Could not replay. Check backend connection.');
      }
    } catch (e) {
      setState(() => _playingId = null);
      _showError('Connection error');
    }
  }

  void _deleteItem(HistoryItem item) {
    setState(() {
      _history.removeWhere((h) => h.id == item.id);
    });
  }

  void _showClearAllDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear History?'),
        content: const Text('This will delete all your conversation history. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _history.clear());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
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
}

class HistoryItem {
  final String id;
  final String originalText;
  final String normalizedText;
  final DateTime timestamp;
  final String? audioBase64;

  HistoryItem({
    String? id,
    required this.originalText,
    required this.normalizedText,
    required this.timestamp,
    this.audioBase64,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  bool get wasEnhanced => originalText != normalizedText;
}

class _HistoryCard extends StatelessWidget {
  final HistoryItem item;
  final bool isPlaying;
  final VoidCallback onPlay;
  final VoidCallback onDelete;

  const _HistoryCard({
    required this.item,
    required this.isPlaying,
    required this.onPlay,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPlaying ? AppColors.primary : AppColors.surfaceVariant,
            width: isPlaying ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timestamp
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  _formatTimestamp(item.timestamp),
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                if (item.wasEnhanced) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_fix_high, size: 12, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          'Enhanced',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // Normalized text (main display)
            Text(
              item.normalizedText,
              style: Theme.of(context).textTheme.bodyLarge,
            ),

            // Original text (if different)
            if (item.wasEnhanced) ...[
              const SizedBox(height: 8),
              Text(
                'Original: "${item.originalText}"',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Play button
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPlay,
                    icon: isPlaying 
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          )
                        : const Icon(Icons.play_arrow, size: 20),
                    label: Text(isPlaying ? 'Playing...' : 'Replay'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
