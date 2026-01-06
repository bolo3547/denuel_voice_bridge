import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/apple/apple_home_screen.dart';
import 'theme/apple_colors.dart';
import 'theme/apple_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppleColors.background,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const DenuelVoiceBridgeApp());
}

/// Denuel Voice Bridge - Apple-Style Edition
/// 
/// A calm, elegant app for people with speech difficulties.
/// Designed with Apple's human interface principles:
/// - Clarity: Text is legible, icons are precise
/// - Deference: UI helps, never competes with content
/// - Depth: Layers and motion provide context
class DenuelVoiceBridgeApp extends StatelessWidget {
  const DenuelVoiceBridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Denuel Voice Bridge',
      debugShowCheckedModeBanner: false,
      theme: AppleTheme.light,
      home: const AppleHomeScreen(),
    );
  }
}
