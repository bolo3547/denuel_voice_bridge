import 'package:flutter/material.dart';
import 'dart:async';
import '../theme.dart';
import '../services/voice_bridge_service.dart';
import 'speak_screen_v3.dart';
import 'quick_phrases_screen.dart';
import 'type_to_speak_screen.dart';
import 'history_screen.dart';

/// HomeScreenV3 - Main navigation hub with improved UX
/// 
/// Bottom navigation with 4 main sections:
/// 1. Speak - Voice recording (main feature)
/// 2. Quick - Pre-saved phrases
/// 3. Type - Type to speak
/// 4. History - Past conversations

class HomeScreenV3 extends StatefulWidget {
  const HomeScreenV3({super.key});

  @override
  State<HomeScreenV3> createState() => _HomeScreenV3State();
}

class _HomeScreenV3State extends State<HomeScreenV3> {
  int _currentIndex = 0;
  bool _backendConnected = false;
  
  final List<Widget> _screens = const [
    SpeakScreenV3(),
    QuickPhrasesScreen(),
    TypeToSpeakScreen(),
    HistoryScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _checkBackend();
    // Periodically check connection
    Timer.periodic(const Duration(seconds: 30), (_) => _checkBackend());
  }

  Future<void> _checkBackend() async {
    final connected = await VoiceBridgeService.isServerRunning();
    if (mounted) {
      setState(() => _backendConnected = connected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Main content
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          
          // Connection status indicator (top right)
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 70, // Leave room for settings icon
            child: _buildConnectionIndicator(),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildConnectionIndicator() {
    return GestureDetector(
      onTap: _showConnectionInfo,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _backendConnected 
              ? AppColors.success.withOpacity(0.15)
              : AppColors.warning.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _backendConnected 
                ? AppColors.success.withOpacity(0.4)
                : AppColors.warning.withOpacity(0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _backendConnected ? AppColors.success : AppColors.warning,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (_backendConnected ? AppColors.success : AppColors.warning)
                        .withOpacity(0.5),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text(
              _backendConnected ? 'Ready' : 'Offline',
              style: TextStyle(
                color: _backendConnected ? AppColors.success : AppColors.warning,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showConnectionInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _backendConnected 
                    ? AppColors.success.withOpacity(0.15)
                    : AppColors.warning.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _backendConnected ? Icons.cloud_done : Icons.cloud_off,
                color: _backendConnected ? AppColors.success : AppColors.warning,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _backendConnected ? 'Connected' : 'Offline Mode',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _backendConnected 
                  ? '✅ Voice Bridge is fully operational!\n\n'
                    '• Speech recognition with Whisper\n'
                    '• Pronunciation correction\n'
                    '• Voice cloning with XTTS'
                  : '⚠️ Backend server not detected.\n\n'
                    'To enable full features, start the server:\n\n'
                    'cd denuel_voice_bridge\n'
                    'python ai/api/voice_bridge_server.py',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _checkBackend();
            },
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.mic_rounded, 'Speak', isPrimary: true),
              _buildNavItem(1, Icons.flash_on_rounded, 'Quick'),
              _buildNavItem(2, Icons.keyboard_rounded, 'Type'),
              _buildNavItem(3, Icons.history_rounded, 'History'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, {bool isPrimary = false}) {
    final isSelected = _currentIndex == index;
    
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 20 : 16,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: isSelected 
              ? (isPrimary ? AppColors.primary : AppColors.primary).withOpacity(0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected 
                  ? (isPrimary ? AppColors.primary : AppColors.primary)
                  : AppColors.textSecondary,
              size: isSelected ? 26 : 24,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isPrimary ? AppColors.primary : AppColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
