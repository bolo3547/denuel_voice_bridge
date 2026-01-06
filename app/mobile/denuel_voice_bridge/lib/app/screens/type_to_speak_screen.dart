import 'package:flutter/material.dart';
import 'dart:html' as html;
import '../theme.dart';
import '../services/voice_bridge_service.dart';

/// TypeToSpeakScreen - Type text and have it spoken in your voice
/// 
/// Features:
/// - Large text input area
/// - Character counter
/// - Speak button with processing indicator
/// - Recent texts history
/// - Quick text suggestions

class TypeToSpeakScreen extends StatefulWidget {
  const TypeToSpeakScreen({super.key});

  @override
  State<TypeToSpeakScreen> createState() => _TypeToSpeakScreenState();
}

class _TypeToSpeakScreenState extends State<TypeToSpeakScreen> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  
  bool _isProcessing = false;
  bool _isPlaying = false;
  html.AudioElement? _audioPlayer;
  
  // Recent texts (would be persisted in real app)
  final List<String> _recentTexts = [];
  
  // Quick suggestions
  final List<String> _suggestions = [
    'Hello, how are you?',
    'Thank you for your help',
    'Could you please repeat that?',
    'I\'ll be right back',
    'Nice to meet you',
  ];

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    _audioPlayer?.pause();
    super.dispose();
  }

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
                    'Type to Speak',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Type your message and hear it in your voice',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Text input area
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _focusNode.hasFocus 
                              ? AppColors.primary 
                              : AppColors.surfaceVariant,
                          width: _focusNode.hasFocus ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          TextField(
                            controller: _textController,
                            focusNode: _focusNode,
                            maxLines: 6,
                            maxLength: 500,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              height: 1.6,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Type what you want to say...',
                              hintStyle: TextStyle(color: AppColors.textSecondary),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.all(20),
                              counterText: '',
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          // Character counter and clear
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                            child: Row(
                              children: [
                                Text(
                                  '${_textController.text.length}/500',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                const Spacer(),
                                if (_textController.text.isNotEmpty)
                                  GestureDetector(
                                    onTap: () {
                                      _textController.clear();
                                      setState(() {});
                                    },
                                    child: Text(
                                      'Clear',
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Speak button
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton(
                        onPressed: _textController.text.trim().isEmpty || _isProcessing
                            ? null
                            : _speakText,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppColors.surfaceVariant,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: _isProcessing ? 0 : 4,
                        ),
                        child: _isProcessing
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    _isPlaying ? 'Playing...' : 'Processing...',
                                    style: const TextStyle(fontSize: 18),
                                  ),
                                ],
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.volume_up_rounded, size: 28),
                                  SizedBox(width: 12),
                                  Text(
                                    'Speak This',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Quick suggestions
                    Text(
                      'Quick Suggestions',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _suggestions.map((text) => 
                        _SuggestionChip(
                          text: text,
                          onTap: () {
                            _textController.text = text;
                            _textController.selection = TextSelection.collapsed(
                              offset: text.length,
                            );
                            setState(() {});
                          },
                        ),
                      ).toList(),
                    ),

                    // Recent texts
                    if (_recentTexts.isNotEmpty) ...[
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Text(
                            'Recent',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => setState(() => _recentTexts.clear()),
                            child: const Text('Clear All'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...(_recentTexts.take(5).map((text) => 
                        _RecentTextTile(
                          text: text,
                          onTap: () {
                            _textController.text = text;
                            setState(() {});
                          },
                          onSpeak: () => _speakDirectly(text),
                        ),
                      )),
                    ],

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _speakText() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      final result = await VoiceBridgeService.processText(text);
      
      if (!mounted) return;

      if (result['success'] == true && result['audio_base64'] != null) {
        // Add to recent
        _recentTexts.remove(text);
        _recentTexts.insert(0, text);
        if (_recentTexts.length > 10) _recentTexts.removeLast();

        // Play audio
        setState(() => _isPlaying = true);
        
        _audioPlayer?.pause();
        final dataUrl = 'data:audio/wav;base64,${result['audio_base64']}';
        _audioPlayer = html.AudioElement(dataUrl);
        
        _audioPlayer!.onEnded.listen((_) {
          if (mounted) {
            setState(() {
              _isProcessing = false;
              _isPlaying = false;
            });
          }
        });
        
        _audioPlayer!.play();
      } else {
        setState(() {
          _isProcessing = false;
          _isPlaying = false;
        });
        _showError('Could not generate speech. Check backend connection.');
      }
    } catch (e) {
      print('Error speaking text: $e');
      setState(() {
        _isProcessing = false;
        _isPlaying = false;
      });
      _showError('Connection error. Make sure the backend is running.');
    }
  }

  Future<void> _speakDirectly(String text) async {
    _textController.text = text;
    setState(() {});
    await _speakText();
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

class _SuggestionChip extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _SuggestionChip({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.surfaceVariant),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _RecentTextTile extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final VoidCallback onSpeak;

  const _RecentTextTile({
    required this.text,
    required this.onTap,
    required this.onSpeak,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.history, size: 20, color: AppColors.textSecondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.play_circle_outline, color: AppColors.primary),
                  onPressed: onSpeak,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
