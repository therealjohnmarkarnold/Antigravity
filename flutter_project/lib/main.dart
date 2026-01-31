import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/main_menu_screen.dart';

void main() {
  runApp(const FlagMasterApp());
}

class FlagMasterApp extends StatelessWidget {
  const FlagMasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flag Master',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3B82F6)),
        scaffoldBackgroundColor: const Color(0xFFE0F7FA), // Retain Light Blue Background
        useMaterial3: true,
        textTheme: GoogleFonts.outfitTextTheme(),
      ),
      home: const MainMenuScreen(),
    );
  }
}
