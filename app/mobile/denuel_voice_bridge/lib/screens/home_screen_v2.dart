import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

class HomeScreenV2 extends StatefulWidget {
  const HomeScreenV2({super.key});

  @override
  State<HomeScreenV2> createState() => _HomeScreenV2State();
}

class _HomeScreenV2State extends State<HomeScreenV2> with TickerProviderStateMixin {
  // Recording
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  
  bool _isRecording = false;
  bool _isPlaying = false;
  bool _hasRecording = false;
  String? _recordingPath;
  Duration _recordingDuration = Duration.zero;
  Duration _playbackPosition = Duration.zero;
  Duration _playbackDuration = Duration.zero;
  Timer? _recordingTimer;
  
  // Animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  // Bottom nav
  int _currentIndex = 0;
  
  // Recordings list
  List<RecordingItem> _recordings = [];

  @override
  void initState() {
    super.initState();
    _initAnimation();
    _initAudioPlayer();
    _requestPermissions();
  }

  void _initAnimation() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _initAudioPlayer() {
    _player.onPositionChanged.listen((position) {
      setState(() => _playbackPosition = position);
    });
    _player.onDurationChanged.listen((duration) {
      setState(() => _playbackDuration = duration);
    });
    _player.onPlayerComplete.listen((_) {
      setState(() {
        _isPlaying = false;
        _playbackPosition = Duration.zero;
      });
    });
    // Add error handling for playback failures
    _player.onLog.listen((log) {
      debugPrint('AudioPlayer log: $log');
    });
  }

  Future<void> _requestPermissions() async {
    await Permission.microphone.request();
  }

  Future<void> _startRecording() async {
    try {
      if (!await _recorder.hasPermission()) {
        await Permission.microphone.request();
        if (!await _recorder.hasPermission()) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission denied')),
          );
          return;
        }
      }

      String recordPath;
      RecordConfig config;
      
      if (kIsWeb) {
        // On web, use webm/opus format which is better supported
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        recordPath = 'recording_$timestamp.webm';
        config = const RecordConfig(
          encoder: AudioEncoder.opus,
          bitRate: 128000,
          sampleRate: 44100,
        );
      } else {
        // On native, use m4a/aac format
        final dir = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        recordPath = '${dir.path}/recording_$timestamp.m4a';
        config = const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        );
      }

      _recordingPath = recordPath;
      debugPrint('Starting recording to: $recordPath');
      
      await _recorder.start(config, path: recordPath);

      setState(() {
        _isRecording = true;
        _recordingDuration = Duration.zero;
      });

      _pulseController.repeat(reverse: true);
      
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => _recordingDuration += const Duration(seconds: 1));
      });
    } catch (e) {
      debugPrint('Error starting recording: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting recording: $e')),
      );
    }
  }

  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();
    _pulseController.stop();
    _pulseController.reset();
    
    try {
      final path = await _recorder.stop();
      debugPrint('Recording stopped, path: $path');
      
      if (path != null && path.isNotEmpty) {
        // On native, verify the file was actually created
        if (!kIsWeb) {
          final file = File(path);
          if (await file.exists()) {
            final fileSize = await file.length();
            debugPrint('Recording saved: $path, size: $fileSize bytes');
            if (fileSize == 0) {
              debugPrint('Warning: Recording file is empty!');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Recording failed - file is empty')),
              );
              setState(() {
                _isRecording = false;
                _hasRecording = false;
              });
              return;
            }
          } else {
            debugPrint('Recording file was not created');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Recording failed - file not created')),
            );
            setState(() {
              _isRecording = false;
              _hasRecording = false;
            });
            return;
          }
        }
        
        setState(() {
          _isRecording = false;
          _hasRecording = true;
          _recordingPath = path;
          
          // Add to recordings list
          _recordings.insert(0, RecordingItem(
            path: path,
            duration: _recordingDuration,
            createdAt: DateTime.now(),
          ));
        });
        
        debugPrint('Recording completed successfully');
      } else {
        debugPrint('Recording returned null/empty path');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recording failed')),
        );
        setState(() {
          _isRecording = false;
          _hasRecording = false;
        });
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error stopping recording: $e')),
      );
      setState(() {
        _isRecording = false;
        _hasRecording = false;
      });
    }
  }

  Future<void> _playRecording() async {
    if (_recordingPath == null) {
      debugPrint('No recording path available');
      return;
    }

    debugPrint('Attempting to play: $_recordingPath');

    if (_isPlaying) {
      await _player.pause();
      setState(() => _isPlaying = false);
    } else {
      try {
        // Use UrlSource on web, DeviceFileSource on native platforms
        if (kIsWeb) {
          debugPrint('Playing on web with UrlSource');
          await _player.play(UrlSource(_recordingPath!));
        } else {
          // Verify file exists before playing
          final file = File(_recordingPath!);
          if (!await file.exists()) {
            debugPrint('Recording file does not exist: $_recordingPath');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Recording file not found')),
            );
            return;
          }
          final fileSize = await file.length();
          debugPrint('File exists, size: $fileSize bytes');
          if (fileSize == 0) {
            debugPrint('Recording file is empty');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Recording file is empty')),
            );
            return;
          }
          debugPrint('Playing on native with DeviceFileSource');
          await _player.play(DeviceFileSource(_recordingPath!));
        }
        setState(() => _isPlaying = true);
      } catch (e) {
        debugPrint('Error playing recording: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing: $e')),
        );
        setState(() => _isPlaying = false);
      }
    }
  }

  Future<void> _playRecordingItem(RecordingItem item) async {
    try {
      await _player.stop();
      debugPrint('Playing recording item: ${item.path}');
      if (kIsWeb) {
        await _player.play(UrlSource(item.path));
      } else {
        // Verify file exists
        final file = File(item.path);
        if (!await file.exists()) {
          debugPrint('Recording item file not found: ${item.path}');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Recording file not found')),
          );
          return;
        }
        await _player.play(DeviceFileSource(item.path));
      }
      setState(() => _isPlaying = true);
    } catch (e) {
      debugPrint('Error playing recording item: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error playing: $e')),
      );
    }
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${twoDigits(d.inMinutes)}:${twoDigits(d.inSeconds.remainder(60))}';
  }

  @override
  void dispose() {
    _recorder.dispose();
    _player.dispose();
    _pulseController.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0F),
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: [
            _buildRecordingTab(),
            _buildHistoryTab(),
            _buildSettingsTab(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildRecordingTab() {
    return Column(
      children: [
        _buildAppBar('Voice Bridge'),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Status indicator
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  _isRecording 
                      ? 'Recording...' 
                      : _hasRecording 
                          ? 'Recording saved' 
                          : 'Tap to record',
                  key: ValueKey(_isRecording),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: _isRecording 
                        ? const Color(0xFFFF4757) 
                        : Colors.white70,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Duration
              Text(
                _formatDuration(_recordingDuration),
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w200,
                  color: Colors.white,
                  fontFamily: 'monospace',
                  letterSpacing: 4,
                ),
              ),
              
              const SizedBox(height: 60),
              
              // Record button
              GestureDetector(
                onTap: _isRecording ? _stopRecording : _startRecording,
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _isRecording ? _pulseAnimation.value : 1.0,
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: _isRecording
                                ? [const Color(0xFFFF4757), const Color(0xFFFF6B81)]
                                : [const Color(0xFF667EEA), const Color(0xFF764BA2)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (_isRecording 
                                  ? const Color(0xFFFF4757) 
                                  : const Color(0xFF667EEA)).withOpacity(0.4),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Icon(
                          _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                          size: 56,
                          color: Colors.white,
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              const SizedBox(height: 60),
              
              // Playback controls
              if (_hasRecording) ...[
                _buildPlaybackCard(),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlaybackCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1F),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Play button
              GestureDetector(
                onTap: _playRecording,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                    ),
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Progress
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Latest Recording',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Seek slider (allows scrubbing)
                    Slider(
                      value: _playbackDuration.inMilliseconds > 0
                          ? _playbackPosition.inMilliseconds.toDouble()
                          : 0.0,
                      max: _playbackDuration.inMilliseconds > 0
                          ? _playbackDuration.inMilliseconds.toDouble()
                          : 1.0,
                      onChanged: (_playbackDuration.inMilliseconds > 0)
                          ? (value) async {
                              final pos = Duration(milliseconds: value.toInt());
                              await _player.seek(pos);
                              setState(() => _playbackPosition = pos);
                            }
                          : null,
                      activeColor: const Color(0xFF667EEA),
                      inactiveColor: Colors.white.withOpacity(0.1),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(_playbackPosition),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          _formatDuration(_playbackDuration > Duration.zero ? _playbackDuration : _recordingDuration),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.transcribe,
                  label: 'Transcribe',
                  onTap: () => _showFeatureDialog('Transcription'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.record_voice_over,
                  label: 'Clone Voice',
                  onTap: () => _showFeatureDialog('Voice Cloning'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.share_rounded,
                  label: 'Share',
                  onTap: () => _showFeatureDialog('Share'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF667EEA), size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    return Column(
      children: [
        _buildAppBar('History'),
        Expanded(
          child: _recordings.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: 64,
                        color: Colors.white.withOpacity(0.2),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No recordings yet',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Start recording to see your history',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _recordings.length,
                  itemBuilder: (context, index) {
                    final item = _recordings[index];
                    return _buildRecordingTile(item, index);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildRecordingTile(RecordingItem item, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _playRecordingItem(item),
            child: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                ),
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recording ${_recordings.length - index}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatDuration(item.duration)} • ${_formatDate(item.createdAt)}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert,
              color: Colors.white.withOpacity(0.5),
            ),
            color: const Color(0xFF2A2A2F),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.white))),
              const PopupMenuItem(value: 'share', child: Text('Share', style: TextStyle(color: Colors.white))),
            ],
            onSelected: (value) {
              if (value == 'delete') {
                setState(() => _recordings.removeAt(index));
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    return Column(
      children: [
        _buildAppBar('Settings'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSettingsSection('Account', [
                _buildSettingsTile(Icons.person_outline, 'Profile', 'Manage your account'),
                _buildSettingsTile(Icons.cloud_outlined, 'Cloud Sync', 'Sync recordings to cloud'),
                _buildSettingsTile(Icons.workspace_premium_outlined, 'Upgrade to Pro', 'Get unlimited features'),
              ]),
              const SizedBox(height: 24),
              _buildSettingsSection('Voice', [
                _buildSettingsTile(Icons.record_voice_over_outlined, 'Voice Profiles', 'Manage saved voices'),
                _buildSettingsTile(Icons.language, 'Language', 'English (US)'),
                _buildSettingsTile(Icons.speed, 'Speech Rate', 'Normal'),
              ]),
              const SizedBox(height: 24),
              _buildSettingsSection('App', [
                _buildSettingsTile(Icons.dark_mode_outlined, 'Theme', 'Dark'),
                _buildSettingsTile(Icons.notifications_outlined, 'Notifications', 'Enabled'),
                _buildSettingsTile(Icons.info_outline, 'About', 'Version 2.0.0'),
              ]),
              const SizedBox(height: 32),
              Center(
                child: Text(
                  'Denuel Voice Bridge v2.0.0',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.3),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1F),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, String subtitle) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF667EEA).withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: const Color(0xFF667EEA), size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Colors.white.withOpacity(0.4),
          fontSize: 13,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: Colors.white.withOpacity(0.3),
      ),
      onTap: () {},
    );
  }

  Widget _buildAppBar(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1F),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1F),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(0, Icons.mic_rounded, 'Record'),
          _buildNavItem(1, Icons.history_rounded, 'History'),
          _buildNavItem(2, Icons.settings_rounded, 'Settings'),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF667EEA).withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? const Color(0xFF667EEA) : Colors.white.withOpacity(0.5),
              size: 26,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? const Color(0xFF667EEA) : Colors.white.withOpacity(0.5),
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFeatureDialog(String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          feature,
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          'Connect to the Voice Bridge API to enable $feature.',
          style: TextStyle(color: Colors.white.withOpacity(0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Color(0xFF667EEA))),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}

class RecordingItem {
  final String path;
  final Duration duration;
  final DateTime createdAt;
  
  RecordingItem({
    required this.path,
    required this.duration,
    required this.createdAt,
  });
}
