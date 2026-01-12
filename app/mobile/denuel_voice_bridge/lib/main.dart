import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen_v2.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF1A1A1F),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const DenuelVoiceBridgeApp());
}

class DenuelVoiceBridgeApp extends StatelessWidget {
  const DenuelVoiceBridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Denuel Voice Bridge',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D0D0F),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF667EEA),
          brightness: Brightness.dark,
        ).copyWith(
          primary: const Color(0xFF667EEA),
          secondary: const Color(0xFF764BA2),
          surface: const Color(0xFF1A1A1F),
          background: const Color(0xFF0D0D0F),
        ),
        fontFamily: 'SF Pro Display',
      ),
      home: const HomeScreenV2(),
    );
  }
}
