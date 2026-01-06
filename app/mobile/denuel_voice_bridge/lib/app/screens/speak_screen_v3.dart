import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'dart:math' as math;
import '../theme.dart';
import '../services/voice_bridge_service.dart';

// Web-specific imports
import 'dart:html' as html;
import 'dart:js' as js;

/// SpeakScreenV3 - Enhanced voice recording screen
/// 
/// Features:
/// - Large, accessible mic button
/// - Real-time waveform visualization
/// - Live transcription display
/// - Clear visual feedback for all states
/// - Playback controls for original vs processed

class SpeakScreenV3 extends StatefulWidget {
  const SpeakScreenV3({super.key});

  @override
  State<SpeakScreenV3> createState() => _SpeakScreenV3State();
}

class _SpeakScreenV3State extends State<SpeakScreenV3>
    with TickerProviderStateMixin {
  
  // State
  bool _isRecording = false;
  bool _isProcessing = false;
  bool _hasPermission = false;
  bool _backendConnected = false;
  bool _disposed = false;
  bool _modelsReady = false;
  bool _isWarmingUp = false;
  
  // Processing stages
  String _processingStage = '';  // 'transcribing', 'normalizing', 'generating'
  
  // Text states
  String _recognizedText = '';
  String _normalizedText = '';
  String _statusMessage = 'Tap the microphone to speak';
  
  // Recording
  Duration _recordingDuration = Duration.zero;
  Timer? _durationTimer;
  
  // Web audio
  html.MediaRecorder? _mediaRecorder;
  html.MediaStream? _mediaStream;
  List<html.Blob> _audioChunks = [];
  String? _audioUrl;
  String? _processedAudioBase64;
  html.AudioElement? _audioPlayer;
  
  // Speech recognition
  dynamic _speechRecognition;
  bool _speechRecognitionActive = false;
  
  // Animations
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late Animation<double> _pulseAnimation;
  
  // Waveform
  List<double> _waveformData = List.generate(40, (i) => 0.1);
  Timer? _waveformTimer;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _checkPermissions();
    _checkBackendConnection();
    _initSpeechRecognition();
  }

  @override
  void dispose() {
    _disposed = true;
    _durationTimer?.cancel();
    _waveformTimer?.cancel();
    _mediaStream?.getTracks().forEach((track) => track.stop());
    _pulseController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  Future<void> _checkBackendConnection() async {
    final connected = await VoiceBridgeService.isServerRunning();
    if (mounted) {
      setState(() {
        _backendConnected = connected;
        _modelsReady = VoiceBridgeService.modelsReady;
      });
      
      // If connected but models not ready, show warmup option
      if (connected && !VoiceBridgeService.modelsReady) {
        _warmupModels();
      }
    }
  }
  
  Future<void> _warmupModels() async {
    if (_isWarmingUp) return;
    
    setState(() {
      _isWarmingUp = true;
      _statusMessage = 'Loading AI models... (first time only)';
    });
    
    final ready = await VoiceBridgeService.warmupModels();
    
    if (mounted) {
      setState(() {
        _isWarmingUp = false;
        _modelsReady = ready;
        _statusMessage = ready 
            ? 'Ready! Tap the microphone to speak'
            : 'Tap the microphone to speak';
      });
    }
  }

  Future<void> _checkPermissions() async {
    if (kIsWeb) {
      try {
        final stream = await html.window.navigator.mediaDevices?.getUserMedia({'audio': true});
        if (stream != null) {
          stream.getTracks().forEach((track) => track.stop());
          if (mounted) {
            setState(() => _hasPermission = true);
          }
        }
      } catch (e) {
        print('Microphone permission denied: $e');
      }
    }
  }

  void _initSpeechRecognition() {
    if (kIsWeb) {
      try {
        final speechRecognition = js.context['webkitSpeechRecognition'] ?? 
                                   js.context['SpeechRecognition'];
        if (speechRecognition != null) {
          _speechRecognition = js.JsObject(speechRecognition);
          _speechRecognition['continuous'] = true;
          _speechRecognition['interimResults'] = true;
          _speechRecognition['lang'] = 'en-US';
          
          _speechRecognition['onresult'] = js.allowInterop((event) {
            try {
              final jsEvent = event as js.JsObject;
              final results = jsEvent['results'];
              if (results == null) return;
              
              String transcript = '';
              final length = results['length'] as int? ?? 0;
              for (int i = 0; i < length; i++) {
                try {
                  final result = results.callMethod('item', [i]);
                  if (result != null) {
                    final firstAlt = result.callMethod('item', [0]);
                    if (firstAlt != null) {
                      transcript += firstAlt['transcript']?.toString() ?? '';
                    }
                  }
                } catch (e) {}
              }
              if (mounted && transcript.isNotEmpty) {
                setState(() => _recognizedText = transcript);
              }
            } catch (e) {
              print('Error processing speech result: $e');
            }
          });
          
          _speechRecognition['onerror'] = js.allowInterop((event) {
            _speechRecognitionActive = false;
          });
          
          _speechRecognition['onend'] = js.allowInterop((event) {
            _speechRecognitionActive = false;
          });
        }
      } catch (e) {
        print('Speech recognition not available: $e');
      }
    }
  }

  Future<void> _startRecording() async {
    if (!_hasPermission) {
      await _checkPermissions();
      if (!_hasPermission) {
        setState(() => _statusMessage = 'Please allow microphone access');
        return;
      }
    }

    try {
      _audioChunks = [];
      _recognizedText = '';
      _normalizedText = '';
      _processedAudioBase64 = null;
      
      _mediaStream = await html.window.navigator.mediaDevices?.getUserMedia({
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        }
      });

      if (_mediaStream == null) {
        setState(() => _statusMessage = 'Could not access microphone');
        return;
      }

      _mediaRecorder = html.MediaRecorder(_mediaStream!, {'mimeType': 'audio/webm'});
      
      _mediaRecorder!.addEventListener('dataavailable', (event) {
        final blobEvent = event as html.BlobEvent;
        if (blobEvent.data != null && blobEvent.data!.size > 0) {
          _audioChunks.add(blobEvent.data!);
        }
      });

      _mediaRecorder!.addEventListener('stop', (event) {
        _processRecording();
      });

      _mediaRecorder!.start(100);

      // Start animations
      _pulseController.repeat(reverse: true);
      _waveController.repeat();
      
      // Start duration timer
      _recordingDuration = Duration.zero;
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() => _recordingDuration += const Duration(seconds: 1));
        }
      });
      
      // Start waveform animation
      _waveformTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
        if (mounted && _isRecording) {
          setState(() {
            _waveformData = List.generate(40, (i) => 0.2 + math.Random().nextDouble() * 0.8);
          });
        }
      });

      // Start speech recognition
      if (_speechRecognition != null && !_speechRecognitionActive) {
        try {
          _speechRecognition.callMethod('start');
          _speechRecognitionActive = true;
        } catch (e) {}
      }

      setState(() {
        _isRecording = true;
        _statusMessage = 'Listening... Speak naturally';
      });
    } catch (e) {
      print('Error starting recording: $e');
      setState(() => _statusMessage = 'Error starting recording');
    }
  }

  Future<void> _stopRecording() async {
    _durationTimer?.cancel();
    _waveformTimer?.cancel();
    
    if (!_disposed) {
      _pulseController.stop();
      _waveController.stop();
      _pulseController.reset();
      _waveController.reset();
    }

    try {
      if (_speechRecognitionActive) {
        _speechRecognition?.callMethod('stop');
        _speechRecognitionActive = false;
      }
    } catch (e) {}

    if (_mediaRecorder != null && _mediaRecorder!.state == 'recording') {
      _mediaRecorder!.stop();
    }
    
    _mediaStream?.getTracks().forEach((track) => track.stop());
    _mediaStream = null;

    if (!_disposed) {
      setState(() {
        _isRecording = false;
        _waveformData = List.generate(40, (i) => 0.1);
        _statusMessage = 'Processing your speech...';
      });
    }
  }

  void _processRecording() {
    if (_audioChunks.isEmpty) {
      setState(() => _statusMessage = 'No audio recorded. Try again.');
      return;
    }

    setState(() => _isProcessing = true);

    final blob = html.Blob(_audioChunks, 'audio/webm');
    
    if (_audioUrl != null) {
      html.Url.revokeObjectUrl(_audioUrl!);
    }
    _audioUrl = html.Url.createObjectUrl(blob);

    if (_backendConnected) {
      _processWithBackend(blob);
    } else {
      _finishProcessing(false);
    }
  }

  Future<void> _processWithBackend(html.Blob audioBlob) async {
    try {
      setState(() {
        _processingStage = 'transcribing';
        _statusMessage = '🎤 Transcribing your speech...';
      });
      
      final base64Audio = await VoiceBridgeService.blobToBase64(audioBlob);
      
      setState(() {
        _processingStage = 'processing';
        _statusMessage = '🧠 Processing with AI...';
      });
      
      final result = await VoiceBridgeService.processAudio(base64Audio, 'webm');

      if (!mounted) return;

      if (result['success'] == true) {
        setState(() {
          _recognizedText = result['recognized_text'] ?? '';
          _normalizedText = result['normalized_text'] ?? '';
          _processedAudioBase64 = result['audio_base64'] ?? '';
          _processingStage = '';
        });
        _finishProcessing(true);
      } else {
        setState(() => _processingStage = '');
        _finishProcessing(false);
      }
    } catch (e) {
      print('Backend processing error: $e');
      setState(() => _processingStage = '');
      _finishProcessing(false);
    }
  }

  void _finishProcessing(bool success) {
    if (!mounted) return;
    
    setState(() {
      _isProcessing = false;
      if (success && _normalizedText.isNotEmpty) {
        _statusMessage = 'Ready to play!';
      } else if (_recognizedText.isNotEmpty) {
        _statusMessage = 'Processed locally';
      } else {
        _statusMessage = 'No speech detected. Try again.';
      }
    });
    
    if ((_recognizedText.isNotEmpty || _normalizedText.isNotEmpty)) {
      _showResultSheet();
    }
  }

  void _playProcessedAudio() {
    if (_processedAudioBase64 != null && _processedAudioBase64!.isNotEmpty) {
      _audioPlayer?.pause();
      final dataUrl = 'data:audio/wav;base64,$_processedAudioBase64';
      _audioPlayer = html.AudioElement(dataUrl);
      _audioPlayer!.play();
    }
  }

  void _playOriginalAudio() {
    if (_audioUrl != null) {
      _audioPlayer?.pause();
      _audioPlayer = html.AudioElement(_audioUrl);
      _audioPlayer!.play();
    }
  }

  void _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  void _showResultSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ResultSheet(
        recognizedText: _recognizedText,
        normalizedText: _normalizedText,
        hasProcessedAudio: _processedAudioBase64 != null && _processedAudioBase64!.isNotEmpty,
        onPlayProcessed: _playProcessedAudio,
        onPlayOriginal: _playOriginalAudio,
        onTryAgain: () {
          Navigator.pop(context);
          _startRecording();
        },
      ),
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${twoDigits(d.inMinutes)}:${twoDigits(d.inSeconds % 60)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Text(
                    'Voice Bridge',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () {
                      // Navigate to settings
                    },
                  ),
                ],
              ),
            ),

            // Status message
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                _statusMessage,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: _isRecording ? AppColors.recording : AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            // Recording duration
            if (_isRecording)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.recording.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: AppColors.recording,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDuration(_recordingDuration),
                        style: const TextStyle(
                          color: AppColors.recording,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const Spacer(),

            // Live transcription box
            if (_recognizedText.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isRecording 
                        ? AppColors.recording.withOpacity(0.3)
                        : AppColors.surfaceVariant,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.hearing,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'I heard:',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _recognizedText,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        height: 1.5,
                      ),
                    ),
                    if (_normalizedText.isNotEmpty && _normalizedText != _recognizedText) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.auto_fix_high,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Enhanced:',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _normalizedText,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          height: 1.5,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            const Spacer(),

            // Waveform visualization
            if (_isRecording)
              SizedBox(
                height: 80,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: _waveformData.map((value) => 
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 80),
                      width: 4,
                      height: 80 * value,
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            AppColors.recording.withOpacity(0.4),
                            AppColors.recording,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ).toList(),
                ),
              ),

            const SizedBox(height: 30),

            // Main mic button
            _buildMicButton(),

            const SizedBox(height: 16),

            // Quick action hint
            if (!_isRecording && !_isProcessing)
              Text(
                _hasPermission 
                    ? 'Tap to start speaking'
                    : 'Tap to enable microphone',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildMicButton() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Animated rings
        if (_isRecording) ...[
          _AnimatedRing(controller: _waveController, delay: 0, size: 180),
          _AnimatedRing(controller: _waveController, delay: 0.25, size: 220),
          _AnimatedRing(controller: _waveController, delay: 0.5, size: 260),
        ],
        
        // Main button
        ScaleTransition(
          scale: _isRecording ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
          child: GestureDetector(
            onTap: _isProcessing ? null : _toggleRecording,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                gradient: _isRecording
                    ? const LinearGradient(
                        colors: [Color(0xFFEF4444), Color(0xFFF87171)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : _isProcessing
                        ? LinearGradient(
                            colors: [Colors.grey.shade500, Colors.grey.shade600],
                          )
                        : AppColors.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (_isRecording ? AppColors.recording : AppColors.primary)
                        .withOpacity(0.4),
                    blurRadius: 30,
                    spreadRadius: 5,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: _isProcessing
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _processingStage == 'transcribing' ? '🎤' : '🧠',
                          style: const TextStyle(fontSize: 20),
                        ),
                      ],
                    )
                  : _isWarmingUp
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 40,
                              height: 40,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              '🔥',
                              style: TextStyle(fontSize: 20),
                            ),
                          ],
                        )
                      : Icon(
                          _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                          color: Colors.white,
                          size: 60,
                        ),
            ),
          ),
        ),
      ],
    );
  }
}

// Animated ring widget
class _AnimatedRing extends StatelessWidget {
  final AnimationController controller;
  final double delay;
  final double size;

  const _AnimatedRing({
    required this.controller,
    required this.delay,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final value = ((controller.value + delay) % 1.0);
        return Container(
          width: size * (0.5 + value * 0.5),
          height: size * (0.5 + value * 0.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.recording.withOpacity((1 - value) * 0.5),
              width: 3,
            ),
          ),
        );
      },
    );
  }
}

// Result sheet widget
class _ResultSheet extends StatelessWidget {
  final String recognizedText;
  final String normalizedText;
  final bool hasProcessedAudio;
  final VoidCallback onPlayProcessed;
  final VoidCallback onPlayOriginal;
  final VoidCallback onTryAgain;

  const _ResultSheet({
    required this.recognizedText,
    required this.normalizedText,
    required this.hasProcessedAudio,
    required this.onPlayProcessed,
    required this.onPlayOriginal,
    required this.onTryAgain,
  });

  @override
  Widget build(BuildContext context) {
    final hasEnhancements = normalizedText.isNotEmpty && normalizedText != recognizedText;
    
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
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
          const SizedBox(height: 24),
          
          // Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.check_circle,
                  color: AppColors.success,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Voice Captured!',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // What was heard
          if (recognizedText.isNotEmpty) ...[
            Text(
              'What I heard:',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                recognizedText,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ],
          
          // Enhanced version (if different)
          if (hasEnhancements) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(Icons.auto_fix_high, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  'Enhanced for clarity:',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Text(
                normalizedText,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          
          const SizedBox(height: 28),
          
          // Playback buttons
          Row(
            children: [
              // Play enhanced (primary action)
              if (hasProcessedAudio)
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: onPlayProcessed,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(hasEnhancements ? 'Play Enhanced' : 'Play'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              
              if (hasProcessedAudio && hasEnhancements) ...[
                const SizedBox(width: 12),
                // Play original (secondary)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPlayOriginal,
                    icon: const Icon(Icons.hearing, size: 18),
                    label: const Text('Original'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Try again button
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: onTryAgain,
              icon: const Icon(Icons.refresh),
              label: const Text('Record Again'),
            ),
          ),
          
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}
