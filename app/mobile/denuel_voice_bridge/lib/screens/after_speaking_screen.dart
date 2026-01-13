import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/safe_button.dart';
import '../services/session_service.dart';
import '../app/services/voice_bridge_service.dart';
import 'home_screen.dart';
import 'speak_screen.dart';

/// AFTER SPEAKING SCREEN
/// 
/// UX Purpose:
/// - Immediate positive reinforcement: "Thank you. I understood you."
/// - No corrections, no scores, no feedback on "how well" they spoke
/// - Clear options: listen back, try again, or go home
/// - Maintains the calm, safe feeling
/// 
/// Accessibility:
/// - Success state uses same soft colors (no jarring green)
/// - Clear button hierarchy
/// - Screen reader announces success
class AfterSpeakingScreen extends StatefulWidget {
  const AfterSpeakingScreen({super.key});

  @override
  State<AfterSpeakingScreen> createState() => _AfterSpeakingScreenState();
}

class _AfterSpeakingScreenState extends State<AfterSpeakingScreen> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            children: [
              const Spacer(flex: 1),
              
              // Success message container
              Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.success.withOpacity(0.15),
                      blurRadius: 32,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Gentle success icon
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_rounded,
                        size: 40,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Main message
                    Text(
                      'Thank you.',
                      style: AppTextStyles.headline2,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'I understood you.',
                      style: AppTextStyles.reassuring.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              const Spacer(flex: 2),
              
              // Action buttons
              SafeButton(
                icon: Icons.volume_up_rounded,
                label: 'Listen to the clear version',
                onPressed: () => _showListeningDialog(context),
                isPrimary: true,
              ),
              
              const SizedBox(height: 16),
              
              SafeButton(
                icon: Icons.refresh_rounded,
                label: 'Speak again',
                onPressed: () {
                  // Replace current screen with speak screen
                  Navigator.pushReplacement(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) => 
                          const SpeakScreen(),
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 16),
              
              SafeButton(
                icon: Icons.home_rounded,
                label: 'Back home',
                onPressed: () {
                  // Go back to home, clearing the stack
                  Navigator.pushAndRemoveUntil(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) => 
                          const HomeScreen(),
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                    ),
                    (route) => false,
                  );
                },
              ),
              
              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> _getProcessedAudioAndAnnotations() async {
    // 1) Check last processed audio held in VoiceBridgeService
    final global = VoiceBridgeService.getLastProcessedAudioBase64();
    final metricsService = context.read<SpeechMetricsService>();

    if (global != null && global.isNotEmpty) {
      return {
        'base64': global,
        'segments': metricsService.lastMetrics?.phonemeSegments ?? [],
      };
    }

    // 2) Check latest session for processed audio and annotations
    final sessionService = context.read<SessionService>();
    final mostRecent = sessionService.recentSessions.isNotEmpty ? sessionService.recentSessions.first : null;
    if (mostRecent?.processedAudioBase64 != null && mostRecent!.processedAudioBase64!.isNotEmpty) {
      return {
        'base64': mostRecent.processedAudioBase64,
        'segments': mostRecent.finalMetrics?.phonemeSegments ?? [],
      };
    }

    // none found
    return {'base64': null, 'segments': <PhonemeSegment>[]};
  }

  void _showListeningDialog(BuildContext context) async {
    final base64 = await _getProcessedAudioBase64();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: AppColors.surfaceLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Playing indicator
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.volume_up_rounded,
                    size: 32,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Playing your voice…',
                  style: AppTextStyles.headline3,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'This is how others will hear you clearly.',
                  style: AppTextStyles.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                if (data['base64'] == null) ...[
                  const SizedBox(height: 12),
                  Text('No processed audio available yet.', style: AppTextStyles.bodySmall),
                ] else ...[
                  const SizedBox(height: 12),
                  _buildPlayerControls(data['base64'] as String, (data['segments'] as List).cast<PhonemeSegment>()),
                ],

                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Done',
                    style: AppTextStyles.buttonSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlayerControls(String base64, List<PhonemeSegment> segments) {
    return Column(
      children: [
        // Play/pause + seek slider
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              iconSize: 48,
              onPressed: () async {
                if (_isPlaying) {
                  if (kIsWeb) {
                    try {
                      // stop web audio
                      final web = (VoiceBridgeService as dynamic)._lastWebAudio as dynamic?;
                      if (web != null) web.pause();
                    } catch (_) {}
                    setState(() => _isPlaying = false);
                  } else {
                    await _player.pause();
                    setState(() => _isPlaying = false);
                  }
                } else {
                  // Play (web or native)
                  if (kIsWeb) {
                    // create controllable html audio element
                    try {
                      final dataUrl = 'data:audio/wav;base64,$base64';
                      final audio = html.AudioElement(dataUrl);
                      audio.autoplay = true;
                      audio.onTimeUpdate.listen((_) {
                        setState(() => _position = Duration(milliseconds: (audio.currentTime * 1000).toInt()));
                      });
                      audio.onDurationChange.listen((_) {
                        setState(() => _duration = Duration(milliseconds: (audio.duration * 1000).toInt()));
                      });
                      audio.onEnded.listen((_) {
                        setState(() {
                          _isPlaying = false;
                          _position = Duration.zero;
                        });
                      });
                      // store reference
                      (VoiceBridgeService as dynamic).setLastProcessedAudioBase64(base64);
                      (VoiceBridgeService as dynamic)._lastWebAudio = audio;
                      audio.play();
                      setState(() => _isPlaying = true);
                    } catch (e) {
                      debugPrint('Web playback error: $e');
                    }
                  } else {
                    final bytes = base64Decode(base64);
                    final dir = await getTemporaryDirectory();
                    final file = File('${dir.path}/processed_${DateTime.now().millisecondsSinceEpoch}.wav');
                    await file.writeAsBytes(bytes);
                    await _player.play(DeviceFileSource(file.path));
                    _player.onPlayerComplete.listen((_) {
                      setState(() => _isPlaying = false);
                    });
                    _player.onPositionChanged.listen((pos) {
                      setState(() => _position = pos);
                    });
                    _player.onDurationChanged.listen((dur) {
                      setState(() => _duration = dur);
                    });
                    setState(() => _isPlaying = true);
                  }
                }
              },
              icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill, color: AppColors.primary),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Slider
        if (_duration.inMilliseconds > 0)
          Slider(
            min: 0,
            max: _duration.inMilliseconds.toDouble(),
            value: _position.inMilliseconds.clamp(0, _duration.inMilliseconds).toDouble(),
            onChanged: (v) async {
              final pos = Duration(milliseconds: v.toInt());
              setState(() => _position = pos);
              if (kIsWeb) {
                try {
                  final web = (VoiceBridgeService as dynamic)._lastWebAudio as dynamic?;
                  if (web != null) web.currentTime = pos.inMilliseconds / 1000.0;
                } catch (_) {}
              } else {
                await _player.seek(pos);
              }
            },
          ),

        // Annotations timeline
        if (segments.isNotEmpty && _duration.inMilliseconds > 0) ...[
          SizedBox(
            height: 40,
            child: Stack(
              children: segments.map((seg) {
                final left = (seg.start / _duration.inMilliseconds * 1000).clamp(0, 1000);
                final right = (seg.end / _duration.inMilliseconds * 1000).clamp(0, 1000);
                // use fraction instead
                final leftFrac = seg.start / (_duration.inMilliseconds / 1000.0);
                final widthFrac = (seg.end - seg.start) / (_duration.inMilliseconds / 1000.0);

                return Positioned(
                  left: leftFrac * MediaQuery.of(context).size.width * 0.85,
                  width: widthFrac * MediaQuery.of(context).size.width * 0.85,
                  top: 8,
                  bottom: 8,
                  child: GestureDetector(
                    onTap: () async {
                      final target = Duration(milliseconds: (seg.start * 1000).toInt());
                      setState(() => _position = target);
                      if (kIsWeb) {
                        try {
                          final web = (VoiceBridgeService as dynamic)._lastWebAudio as dynamic?;
                          if (web != null) web.currentTime = seg.start;
                        } catch (_) {}
                      } else {
                        await _player.seek(target);
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            _getConfidenceColor(seg.confidence).withOpacity(0.8),
                            _getConfidenceColor(seg.confidence).withOpacity(0.4),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _getConfidenceColor(seg.confidence).withOpacity(0.6),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            seg.phoneme,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${(seg.confidence * 100).toInt()}%',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
        ],

        // Progress text
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_formatDuration(_position), style: AppTextStyles.bodySmall),
              Text(_formatDuration(_duration), style: AppTextStyles.bodySmall),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final min = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final sec = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$min:$sec';
  }

  /// Returns a color based on the confidence score (0.0 - 1.0)
  /// Green for high confidence, yellow for medium, red for low
  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) {
      // High confidence: Green
      return const Color(0xFF4CAF50);
    } else if (confidence >= 0.6) {
      // Medium-high: Light green
      return const Color(0xFF8BC34A);
    } else if (confidence >= 0.4) {
      // Medium: Yellow/Orange
      return const Color(0xFFFFC107);
    } else if (confidence >= 0.2) {
      // Medium-low: Orange
      return const Color(0xFFFF9800);
    } else {
      // Low confidence: Red
      return const Color(0xFFF44336);
    }
  }
}

