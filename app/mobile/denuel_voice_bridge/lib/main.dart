import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/home_screen.dart';

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
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5B9A8B), // Soft teal
          brightness: Brightness.light,
        ).copyWith(
          primary: const Color(0xFF5B9A8B),      // Soft teal
          secondary: const Color(0xFF7EC8B8),    // Light teal
          surface: const Color(0xFFF8F6F4),      // Warm neutral
          background: const Color(0xFFFAF9F7),   // Warm white
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: const Color(0xFF2D3436),    // Soft black
        ),
        textTheme: GoogleFonts.poppinsTextTheme().copyWith(
          displayLarge: GoogleFonts.poppins(
            fontSize: 32,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF2D3436),
          ),
          headlineMedium: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF2D3436),
          ),
          bodyLarge: GoogleFonts.nunito(
            fontSize: 18,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF636E72),
          ),
          bodyMedium: GoogleFonts.nunito(
            fontSize: 16,
            color: const Color(0xFF636E72),
          ),
          labelLarge: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 64),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          ),
        ),
        cardTheme: CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          color: Colors.white,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
