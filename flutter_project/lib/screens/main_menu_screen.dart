import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/storage_service.dart';
import 'game_screen.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  int _highScore = 0;
  final StorageService _storage = StorageService();

  @override
  void initState() {
    super.initState();
    _loadHighScore();
  }

  Future<void> _loadHighScore() async {
    final score = await _storage.getHighScore();
    setState(() {
      _highScore = score;
    });
  }
  
  // Reload high score when returning from game
  void _startGame(BuildContext context, bool isHardMode) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameScreen(isHardMode: isHardMode),
      ),
    );
    _loadHighScore(); 
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // Title
              Text(
                'Flag',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 64,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B), // Dark slate
                  height: 0.9,
                ),
              ),
              Text(
                'Master',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 64,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF3B82F6), // Brand Blue
                  height: 0.9,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Test your global knowledge',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  color: const Color(0xFF64748B), // Slate 500
                  letterSpacing: 1.2,
                ),
              ),
               
              const SizedBox(height: 48),

              // High Score
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                   boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'HIGH SCORE',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF94A3B8),
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      '$_highScore',
                      style: GoogleFonts.outfit(
                        fontSize: 48,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
              
              const Spacer(),
              
              // Buttons
              _buildDifficultyButton(
                context, 
                'Easy Mode', 
                'Show full map', 
                Colors.blueAccent, 
                false
              ),
              const SizedBox(height: 16),
              _buildDifficultyButton(
                 context, 
                'Hard Mode', 
                'Outline Only', 
                const Color(0xFF8B5CF6), // Violet
                true
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDifficultyButton(BuildContext context, String title, String subtitle, Color color, bool isHard) {
    return ElevatedButton(
      onPressed: () => _startGame(context, isHard),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 8,
        shadowColor: color.withValues(alpha: 0.4),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}
