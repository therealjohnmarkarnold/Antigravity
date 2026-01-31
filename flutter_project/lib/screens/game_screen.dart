
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../country_service.dart';
import 'game_over_screen.dart';
import '../widgets/world_map_widget.dart';

class GameScreen extends StatefulWidget {
  final bool isHardMode;
  
  const GameScreen({super.key, required this.isHardMode});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  // Game Data
  List<Country> _allCountries = [];
  bool _isLoading = true;
  String? _errorMessage;

  late Country _targetCountry;
  late List<Country> _options;
  bool _isLocked = false;
  int? _selectedIndex;
  bool? _lastGuessCorrect;
  
  // Stats
  int _score = 0;
  int _timeLeft = 60;
  Timer? _timer;

  // Animations
  late AnimationController _shakeController;

  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  final CountryService _countryService = CountryService();

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadData();
  }
  
  void _setupAnimations() {
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );


    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1)
        .chain(CurveTween(curve: Curves.bounceOut))
        .animate(_scaleController);
  }

  Future<void> _loadData() async {
    try {
      final countries = await _countryService.fetchAllCountries();
      if (mounted) {
        setState(() {
          _allCountries = countries;
          _isLoading = false;
          _startNewRound();
          _startTimer();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        setState(() {
          _timeLeft--;
        });
      } else {
        _endGame();
      }
    });
  }
  
  void _endGame() {
    _timer?.cancel();
    Navigator.pushReplacement(
      context, 
      MaterialPageRoute(builder: (context) => GameOverScreen(score: _score))
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _shakeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  void _startNewRound() {
    if (_allCountries.length < 4) return;

    setState(() {
      _isLocked = false;
      _selectedIndex = null;
      _lastGuessCorrect = null;
      
      // Select Target
      _targetCountry = _allCountries[Random().nextInt(_allCountries.length)];
      
      // Select Distractors
      final Set<Country> optionSet = {_targetCountry};
      while (optionSet.length < 4) {
        optionSet.add(_allCountries[Random().nextInt(_allCountries.length)]);
      }
      
      _options = optionSet.toList()..shuffle();
    });
    _scaleController.reset();
  }

  void _handleGuess(int index, Country country) {
    if (_isLocked) return;

    setState(() {
      _isLocked = true;
      _selectedIndex = index;
    });

    if (country.cca2 == _targetCountry.cca2) {
      // Correct!
      setState(() {
        _lastGuessCorrect = true;
        _score += 10; // Simple scoring
      });
      _scaleController.forward().then((_) async {
        await Future.delayed(const Duration(milliseconds: 800));
        _startNewRound();
      });
    } else {
      // Incorrect
      setState(() => _lastGuessCorrect = false);
      _shakeController.forward().then((_) {
        _shakeController.reset();
        setState(() {
          _isLocked = false; // Allow trying again? Or maybe penalize time?
          // For now, allow retry like original but maybe slight delay
          _selectedIndex = null;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    // Error View
    if (_errorMessage != null) {
       return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text("Error: $_errorMessage")),
       );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFE0F7FA),
      body: SafeArea(
        child: Column(
          children: [
            // Header: Score & Timer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatBox('SCORE', '$_score'),
                  _buildStatBox('TIME', '$_timeLeft'),
                ],
              ),
            ),
            
            // Progress Bar (Visual Timer)
            Container(
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(3),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: _timeLeft / 60.0,
                child: Container(
                  decoration: BoxDecoration(
                    color: _timeLeft < 10 ? Colors.red : Colors.blueAccent,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Target Image
                    Expanded(
                      flex: 4,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: widget.isHardMode 
                            ? SvgPicture.network(
                                'https://raw.githubusercontent.com/djaiss/mapsicon/master/all/${_targetCountry.cca2}/vector.svg',
                                fit: BoxFit.contain,
                                colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
                                placeholderBuilder: (_) => const Center(child: CircularProgressIndicator()),
                              )
                            : WorldMapWidget(targetCode: _targetCountry.cca2),
                      ),

                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Which country is this?",
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Options Grid
                    Expanded(
                      flex: 5,
                      child: _buildOptionsGrid(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatBox(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.black45,
            letterSpacing: 1.0,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildOptionsGrid() {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.3,
      ),
      itemCount: 4,
      itemBuilder: (context, index) {
        final country = _options[index];
        final isSelected = _selectedIndex == index;
        final isCorrect = _lastGuessCorrect == true;
        
        Color borderColor = Colors.white;
        if (isSelected) {
          borderColor = isCorrect ? Colors.green : Colors.red;
        }

        Widget card = Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: isSelected ? 4 : 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF1F2937), width: 1), // Off-black border for accessibility
                  borderRadius: BorderRadius.circular(4),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: Image.network(
                    country.flagUrl,
                    height: 50, // Increased size
                    width: 75,
                    fit: BoxFit.cover,
                    errorBuilder: (c, o, s) => const Icon(Icons.flag, size: 50),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  country.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        );
        
        return GestureDetector(
          onTap: () => _handleGuess(index, country),
          child: isSelected && isCorrect 
              ? ScaleTransition(scale: _scaleAnimation, child: card)
              : card,
        );
      },
    );
  }
}
