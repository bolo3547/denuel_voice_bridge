import 'package:flutter/material.dart';
import 'app/screens/home_screen_v3.dart';
import 'app/theme.dart';

/// DENUEL VOICE BRIDGE - Main App v3
/// 
/// World-class assistive speech application with:
/// - Quick phrases for common situations
/// - Type-to-speak mode
/// - Voice recording with real-time feedback
/// - Conversation history
/// - Accessibility-first design

void main() {
  runApp(const DenuelVoiceBridgeApp());
}

class DenuelVoiceBridgeApp extends StatelessWidget {
  const DenuelVoiceBridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Denuel Voice Bridge',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const HomeScreenV3(),
    );
  }
}
