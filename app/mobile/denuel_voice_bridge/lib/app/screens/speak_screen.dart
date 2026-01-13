import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:convert';
import '../theme.dart';
import '../services/voice_bridge_service.dart';

// Web-specific imports
import 'dart:html' as html;
import 'dart:js' as js;

class SpeakScreen extends StatefulWidget {
  const SpeakScreen({super.key});

  @override
  State<SpeakScreen> createState() => _SpeakScreenState();
}

class _SpeakScreenState extends State<SpeakScreen>
    with TickerProviderStateMixin {
  bool _isRecording = false;
  bool _isProcessing = false;
  bool _hasPermission = false;
  bool _backendConnected = false;
  String? _errorMessage;
  String _recognizedText = '';
  String _normalizedText = '';
  String _feedbackMessage = '';
  Duration _recordingDuration = Duration.zero;
  Timer? _durationTimer;
  bool _disposed = false;
  
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
  
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late Animation<double> _pulseAnimation;
  
  // Waveform data (driven by Web Audio Analyzer on web)
  List<double> _waveformData = List.generate(30, (i) => 0.1);
  // Web Audio analyzer nodes (web only) - use dynamic + JS interop to avoid missing dart:html types
  dynamic _audioContext;
  dynamic _analyser;
  Timer? _waveformTimer; // fallback when analyser isn't available

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _checkPermissions();
    _checkBackendConnection();
    _initSpeechRecognition();
  }

  Future<void> _checkBackendConnection() async {
    final connected = await VoiceBridgeService.isServerRunning();
    if (mounted) {
      setState(() {
        _backendConnected = connected;
      });
      if (!connected) {
        print('⚠️ Backend server not running. Using local-only mode.');
      } else {
        print('✅ Connected to DENUEL VOICE BRIDGE backend');
      }
    }
  }

  void _initSpeechRecognition() {
    if (kIsWeb) {
      try {
        // Check if speech recognition is available
        final speechRecognition = js.context['webkitSpeechRecognition'] ?? 
                                   js.context['SpeechRecognition'];
        if (speechRecognition != null) {
          _speechRecognition = js.JsObject(speechRecognition);
          _speechRecognition['continuous'] = true;
          _speechRecognition['interimResults'] = true;
          _speechRecognition['lang'] = 'en-US';
          
          _speechRecognition['onresult'] = js.allowInterop((event) {
            try {
              // Access results via JsObject properly
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
                } catch (e) {
                  // Skip this result
                }
              }
              if (mounted && transcript.isNotEmpty) {
                setState(() {
                  _recognizedText = transcript;
                });
              }
            } catch (e) {
              print('Error processing speech result: $e');
            }
          });
          
          _speechRecognition['onerror'] = js.allowInterop((event) {
            _speechRecognitionActive = false;
            try {
              final error = (event as js.JsObject)['error']?.toString() ?? 'unknown';
              print('Speech recognition error: $error');
            } catch (e) {
              print('Speech recognition error');
            }
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

  Future<void> _checkPermissions() async {
    if (kIsWeb) {
      try {
        // Request microphone permission
        _mediaStream = await html.window.navigator.mediaDevices?.getUserMedia({
          'audio': true,
        });
        if (_mediaStream != null) {
          setState(() {
            _hasPermission = true;
          });
          // Stop the stream until we need it
          _mediaStream!.getTracks().forEach((track) => track.stop());
          _mediaStream = null;
        }
      } catch (e) {
        setState(() {
          _hasPermission = false;
          _errorMessage = 'Microphone permission denied. Please allow microphone access.';
        });
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    
    // Cancel timers first
    _durationTimer?.cancel();
    _waveformTimer?.cancel();
    
    // Stop media recorder and streams without touching animation controllers
    if (_mediaRecorder != null && _mediaRecorder!.state == 'recording') {
      try {
        _mediaRecorder!.stop();
      } catch (e) {
        // ignore
      }
    }
    _mediaStream?.getTracks().forEach((track) {
      try {
        track.stop();
      } catch (e) {
        // ignore
      }
    });
    _mediaStream = null;
    
    // Stop speech recognition
    try {
      _speechRecognition?.callMethod('stop');
    } catch (e) {
      // ignore
    }
    
    // Close audio context
    try {
      if (_audioContext != null) {
        try {
          _audioContext.callMethod('close');
        } catch (e) {
          // ignore
        }
      }
    } catch (e) {
      // ignore errors on dispose
    }
    _audioContext = null;
    _analyser = null;
    
    // Pause audio player
    _audioPlayer?.pause();
    if (_audioUrl != null) {
      try {
        html.Url.revokeObjectUrl(_audioUrl!);
      } catch (e) {
        // ignore
      }
    }
    
    // Dispose animation controllers last
    _pulseController.dispose();
    _waveController.dispose();
    
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (!_hasPermission) {
      await _checkPermissions();
      if (!_hasPermission) return;
    }

    try {
      _audioChunks.clear();
      _recognizedText = '';
      
      // Get fresh media stream
      _mediaStream = await html.window.navigator.mediaDevices?.getUserMedia({
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        }
      });
      
      if (_mediaStream == null) {
        throw Exception('Failed to get media stream');
      }

      // Create MediaRecorder
      _mediaRecorder = html.MediaRecorder(_mediaStream!, {
        'mimeType': 'audio/webm;codecs=opus'
      });
      
      _mediaRecorder!.addEventListener('dataavailable', (event) {
        final blob = (event as html.BlobEvent).data;
        if (blob != null && blob.size > 0) {
          _audioChunks.add(blob);
        }
      });
      
      _mediaRecorder!.addEventListener('stop', (event) {
        _processRecording();
      });

      _mediaRecorder!.start(100); // Collect data every 100ms
      
      // Start speech recognition (only if not already active)
      try {
        if (!_speechRecognitionActive && _speechRecognition != null) {
          _speechRecognition.callMethod('start');
          _speechRecognitionActive = true;
        }
      } catch (e) {
        print('Could not start speech recognition: $e');
        _speechRecognitionActive = false;
      }

      setState(() {
        _isRecording = true;
        _recordingDuration = Duration.zero;
        _errorMessage = null;
      });
      
      _pulseController.repeat(reverse: true);
      _waveController.repeat();
      
      // Start duration timer
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _recordingDuration += const Duration(seconds: 1);
          });
        }
      });

      // Setup Web Audio Analyser to drive waveform (web only) using JS interop.
      try {
        final acCtor = js.context['AudioContext'] ?? js.context['webkitAudioContext'];
        if (acCtor != null) {
          _audioContext = js.JsObject(acCtor);
          final source = _audioContext.callMethod('createMediaStreamSource', [_mediaStream]);
          _analyser = _audioContext.callMethod('createAnalyser');
          _analyser['fftSize'] = 64; // small size, gives frequencyBinCount = 32
          _analyser['smoothingTimeConstant'] = 0.8;
          source.callMethod('connect', [_analyser]);

          // Animation loop using requestAnimationFrame
          void update(num _) {
            if (!mounted || !_isRecording || _analyser == null) return;
            final bufferLength = (_analyser['frequencyBinCount'] as num).toInt();

            // Try to fill a Dart Uint8List; if getByteFrequencyData doesn't accept it, fallback to JS Uint8Array
            final data = Uint8List(bufferLength);
            var usedData = data;
            var success = true;
            try {
              _analyser.callMethod('getByteFrequencyData', [data]);
            } catch (e) {
              success = false;
            }

            if (!success) {
              final jsData = js.JsObject(js.context['Uint8Array'], [bufferLength]);
              _analyser.callMethod('getByteFrequencyData', [jsData]);
              for (var i = 0; i < bufferLength; i++) {
                data[i] = (jsData[i] ?? 0) as int;
              }
              usedData = data;
            }

            final values = List<double>.generate(30, (i) {
              final bin = ((i / 30) * bufferLength).floor().clamp(0, bufferLength - 1);
              final v = (usedData[bin] / 255.0);
              return 0.05 + v * 0.95; // keep min value so bars remain visible
            });

            final rms = math.sqrt(values.map((v) => v * v).reduce((a, b) => a + b) / values.length);
            final isSilent = rms < 0.03; // threshold for silence

            if (mounted) {
              setState(() {
                _waveformData = isSilent ? List.generate(30, (i) => 0.05) : values;
              });
            }

            html.window.requestAnimationFrame(update);
          }

          html.window.requestAnimationFrame(update);
        } else {
          // Fallback to previous random animation if AudioContext isn't available
          _waveformTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
            if (mounted && _isRecording) {
              setState(() {
                _waveformData = List.generate(30, (i) => 0.2 + math.Random().nextDouble() * 0.8);
              });
            }
          });
        }
      } catch (e) {
        // Fallback to previous random animation if analyser setup fails
        _waveformTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
          if (mounted && _isRecording) {
            setState(() {
              _waveformData = List.generate(30, (i) => 0.2 + math.Random().nextDouble() * 0.8);
            });
          }
        });
      }
      
    } catch (e) {
      setState(() {
        _errorMessage = 'Error starting recording: $e';
      });
    }
  }

  Future<void> _stopRecording() async {
    _durationTimer?.cancel();
    _waveformTimer?.cancel();
    // Close audio context/analyser if present
    try {
      if (_audioContext != null) {
        try {
          _audioContext.callMethod('close');
        } catch (e) {
          // ignore
        }
      }
    } catch (e) {
      // ignore
    }
    _audioContext = null;
    _analyser = null;

    // Stop speech recognition
    try {
      if (_speechRecognitionActive) {
        _speechRecognition?.callMethod('stop');
        _speechRecognitionActive = false;
      }
    } catch (e) {
      print('Could not stop speech recognition: $e');
      _speechRecognitionActive = false;
    }

    if (_mediaRecorder != null && _mediaRecorder!.state == 'recording') {
      _mediaRecorder!.stop();
    }
    
    _mediaStream?.getTracks().forEach((track) => track.stop());
    _mediaStream = null;
    
    // Only access animation controllers if widget is not disposed
    if (!_disposed) {
      _pulseController.stop();
      _waveController.stop();
      _pulseController.reset();
      _waveController.reset();
      
      setState(() {
        _isRecording = false;
        _waveformData = List.generate(30, (i) => 0.1);
      });
    }
  }

  void _processRecording() {
    if (_audioChunks.isEmpty) {
      setState(() {
        _feedbackMessage = 'No audio recorded. Please try again.';
      });
      _showResultSheet(success: false);
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    // Create audio blob
    final blob = html.Blob(_audioChunks, 'audio/webm');
    
    // Revoke old URL if exists
    if (_audioUrl != null) {
      html.Url.revokeObjectUrl(_audioUrl!);
    }
    
    _audioUrl = html.Url.createObjectUrl(blob);
    
    // Process with backend if connected, otherwise analyze locally
    if (_backendConnected) {
      _processWithBackend(blob);
    } else {
      _analyzeRecording();
    }
  }

  Future<void> _processWithBackend(html.Blob audioBlob) async {
    try {
      // Convert blob to base64
      final base64Audio = await VoiceBridgeService.blobToBase64(audioBlob);
      
      // Send to backend for processing
      final result = await VoiceBridgeService.processAudio(base64Audio, 'webm');
      
      if (!mounted) return;
      
      if (result['success'] == true) {
        final recognizedText = result['recognized_text'] ?? '';
        final normalizedText = result['normalized_text'] ?? '';
        final processedAudio = result['audio_base64'] ?? '';
        
        setState(() {
          _recognizedText = recognizedText;
          _normalizedText = normalizedText;
          _processedAudioBase64 = processedAudio;
          _isProcessing = false;
        });
        // Keep last processed audio globally available for quick playback
        VoiceBridgeService.setLastProcessedAudioBase64(processedAudio);
        
        if (recognizedText.isEmpty) {
          setState(() {
            _feedbackMessage = 'We couldn\'t detect any speech. Try speaking louder and clearer.';
          });
          _showResultSheet(success: false);
        } else {
          final wordCount = recognizedText.split(' ').length;
          String feedback;
          
          if (wordCount < 3) {
            feedback = 'Good start! Try speaking a bit more for better results.';
          } else if (wordCount >= 10) {
            feedback = 'Excellent! Clear voice captured with $wordCount words.';
          } else {
            feedback = 'Nice! We captured $wordCount words. Your voice sounds clear.';
          }
          
          // Note if corrections were made
          if (recognizedText != normalizedText) {
            feedback += '\n\n✨ Voice Bridge enhanced your speech for clarity.';
          }
          
          setState(() {
            _feedbackMessage = feedback;
          });
          _showResultSheet(success: true);
        }
      } else {
        // Backend error - fall back to local analysis
        print('Backend error: ${result['error']}');
        _analyzeRecording();
      }
    } catch (e) {
      print('Error processing with backend: $e');
      _analyzeRecording();
    }
  }

  void _analyzeRecording() {
    // Simulate processing time
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      
      final text = _recognizedText.trim();
      String feedback;
      bool success;
      
      if (text.isEmpty) {
        feedback = 'We couldn\'t detect any speech. Try speaking louder and clearer.';
        success = false;
      } else if (text.split(' ').length < 3) {
        feedback = 'Good start! Try speaking a bit more for better voice capture.';
        success = true;
      } else if (text.split(' ').length >= 10) {
        feedback = 'Excellent! Clear voice captured with ${text.split(' ').length} words. Great sample!';
        success = true;
      } else {
        feedback = 'Nice! We captured ${text.split(' ').length} words. Your voice sounds clear.';
        success = true;
      }
      
      setState(() {
        _isProcessing = false;
        _feedbackMessage = feedback;
      });
      
      _showResultSheet(success: success);
    });
  }

  void _playRecording() {
    // Play processed audio if available (from backend), otherwise play original
    if (_processedAudioBase64 != null && _processedAudioBase64!.isNotEmpty) {
      _playProcessedAudio();
    } else if (_audioUrl != null) {
      _audioPlayer?.pause();
      _audioPlayer = html.AudioElement(_audioUrl);
      _audioPlayer!.play();
    }
  }

  void _playProcessedAudio() {
    if (_processedAudioBase64 == null) return;
    
    _audioPlayer?.pause();
    final dataUrl = 'data:audio/wav;base64,$_processedAudioBase64';
    _audioPlayer = html.AudioElement(dataUrl);
    _audioPlayer!.play();
  }

  void _playOriginalRecording() {
    if (_audioUrl == null) return;
    
    _audioPlayer?.pause();
    _audioPlayer = html.AudioElement(_audioUrl);
    _audioPlayer!.play();
  }

  void _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  void _showResultSheet({required bool success}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ResultSheet(
        success: success,
        recognizedText: _recognizedText,
        normalizedText: _normalizedText,
        feedbackMessage: _feedbackMessage,
        duration: _recordingDuration,
        onPlayPressed: _playRecording,
        onPlayOriginal: _processedAudioBase64 != null ? _playOriginalRecording : null,
        onTryAgain: () {
          Navigator.pop(context);
        },
        hasProcessedAudio: _processedAudioBase64 != null && _processedAudioBase64!.isNotEmpty,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Speak'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: () => _showHelpDialog(),
          ),
        ],
      ),
      body: Column(
        children: [
          const Spacer(flex: 1),
          
          // Recording duration
          if (_isRecording)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.recording.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.recording,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatDuration(_recordingDuration),
                    style: TextStyle(
                      color: AppColors.recording,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          
          const SizedBox(height: 16),
          
          // Status text
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              _isProcessing 
                  ? 'Processing...'
                  : _isRecording 
                      ? 'Listening...' 
                      : 'Tap to start',
              key: ValueKey('$_isRecording$_isProcessing'),
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: _isRecording ? AppColors.recording : AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _isRecording 
                  ? 'Speak naturally, take your time'
                  : _hasPermission 
                      ? 'Press the button when ready'
                      : 'Please allow microphone access',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ),
          
          // Show recognized text while recording
          if (_isRecording && _recognizedText.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.surfaceVariant),
              ),
              child: Text(
                _recognizedText,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          
          const Spacer(flex: 1),
          
          // Waveform visualization
          if (_isRecording)
            SizedBox(
              height: 60,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _waveformData.map((value) => 
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    width: 4,
                    height: 60 * value,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: AppColors.recording.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ).toList(),
              ),
            ),
          
          const SizedBox(height: 20),

          // Mic button with waves
          Stack(
            alignment: Alignment.center,
            children: [
              // Animated waves
              if (_isRecording) ...[
                _AnimatedWave(
                  controller: _waveController,
                  delay: 0,
                  size: 200,
                ),
                _AnimatedWave(
                  controller: _waveController,
                  delay: 0.3,
                  size: 240,
                ),
                _AnimatedWave(
                  controller: _waveController,
                  delay: 0.6,
                  size: 280,
                ),
              ],
              
              // Main button
              ScaleTransition(
                scale: _isRecording ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
                child: GestureDetector(
                  onTap: _isProcessing ? null : _toggleRecording,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: _isRecording 
                          ? const LinearGradient(
                              colors: [Color(0xFFEF4444), Color(0xFFF87171)],
                            )
                          : _isProcessing
                              ? LinearGradient(
                                  colors: [Colors.grey.shade400, Colors.grey.shade500],
                                )
                              : AppColors.primaryGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (_isRecording ? AppColors.recording : AppColors.primary)
                              .withOpacity(0.4),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: _isProcessing
                        ? const Center(
                            child: SizedBox(
                              width: 40,
                              height: 40,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            ),
                          )
                        : Icon(
                            _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                            color: Colors.white,
                            size: 48,
                          ),
                  ),
                ),
              ),
            ],
          ),

          const Spacer(flex: 2),

          // Error message
          if (_errorMessage != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.error.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: AppColors.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: AppColors.error, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),

          // Tips section
          Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.surfaceVariant,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.lightbulb_outline_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tip',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      Text(
                        'Speak at a comfortable pace. There\'s no rush.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('How to Record'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HelpStep(number: '1', text: 'Tap the microphone button to start'),
            const SizedBox(height: 12),
            _HelpStep(number: '2', text: 'Speak clearly into your device'),
            const SizedBox(height: 12),
            _HelpStep(number: '3', text: 'Tap the stop button when finished'),
            const SizedBox(height: 12),
            _HelpStep(number: '4', text: 'Review your recording and feedback'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'For best results, use a quiet environment and speak at your normal pace.',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }
}

class _HelpStep extends StatelessWidget {
  final String number;
  final String text;

  const _HelpStep({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ],
    );
  }
}

class _AnimatedWave extends StatelessWidget {
  final AnimationController controller;
  final double delay;
  final double size;

  const _AnimatedWave({
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
              color: AppColors.recording.withOpacity(0.3 * (1 - value)),
              width: 2,
            ),
          ),
        );
      },
    );
  }
}

class _ResultSheet extends StatelessWidget {
  final bool success;
  final String recognizedText;
  final String normalizedText;
  final String feedbackMessage;
  final Duration duration;
  final VoidCallback onPlayPressed;
  final VoidCallback? onPlayOriginal;
  final VoidCallback onTryAgain;
  final bool hasProcessedAudio;

  const _ResultSheet({
    required this.success,
    required this.recognizedText,
    this.normalizedText = '',
    required this.feedbackMessage,
    required this.duration,
    required this.onPlayPressed,
    this.onPlayOriginal,
    required this.onTryAgain,
    this.hasProcessedAudio = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
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
          const SizedBox(height: 24),
          
          // Success/Error icon
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: (success ? AppColors.success : AppColors.error).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              success ? Icons.check_rounded : Icons.refresh_rounded,
              color: success ? AppColors.success : AppColors.error,
              size: 36,
            ),
          ),
          const SizedBox(height: 20),
          
          Text(
            success ? 'Recording Complete!' : 'Try Again',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          
          // Duration
          if (duration.inSeconds > 0)
            Text(
              'Duration: ${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          
          const SizedBox(height: 16),
          
          // Feedback
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.feedback_outlined,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Feedback',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  feedbackMessage,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
          
          // Recognized text
          if (recognizedText.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.text_fields_rounded,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'What we heard',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '"$recognizedText"',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 24),
          
          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onTryAgain,
                  icon: const Icon(Icons.replay_rounded),
                  label: const Text('Try Again'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(color: AppColors.surfaceVariant),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onPlayPressed,
                  icon: Icon(hasProcessedAudio ? Icons.record_voice_over_rounded : Icons.volume_up_rounded),
                  label: Text(hasProcessedAudio ? 'Play Clear' : 'Play'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
          
          // Show original playback option if processed audio exists
          if (hasProcessedAudio && onPlayOriginal != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onPlayOriginal,
              icon: const Icon(Icons.hearing_rounded, size: 18),
              label: const Text('Play Original Recording'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
              ),
            ),
          ],
          
          const SizedBox(height: 12),
          
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Done'),
          ),
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class AnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext, Widget?) builder;
  final Widget? child;

  const AnimatedBuilder({
    super.key,
    required Animation<double> animation,
    required this.builder,
    this.child,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) => builder(context, child);
}
