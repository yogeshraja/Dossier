import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dossier/data/local/initial_data.dart';
import 'package:dossier/features/dossiers/providers/dossier_providers.dart';
import 'package:dossier/features/auth/providers/auth_provider.dart';
import 'package:dossier/features/auth/screens/auth_screen.dart';
import 'package:dossier/main.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;

  late AnimationController _pulseController;
  late Animation<double> _pulseScale;

  late AnimationController _textController;
  late Animation<Offset> _textSlide;
  late Animation<double> _textOpacity;

  String _statusMessage = 'Starting offline engine...';
  double _progressValue = 0.1;
  Timer? _stepTimer;

  @override
  void initState() {
    super.initState();

    // 1. Logo entry animation
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: const Interval(0.0, 0.6, curve: Curves.easeIn)),
    );

    // 2. Continuous pulse glow
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseScale = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // 3. Text slide up
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
    );
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeIn),
    );

    _startBootSequence();
  }

  Future<void> _startBootSequence() async {
    _logoController.forward();
    await Future.delayed(const Duration(milliseconds: 250));
    _textController.forward();

    // Initialize Database
    setState(() {
      _statusMessage = 'Initializing local Drift SQLite vault...';
      _progressValue = 0.35;
    });

    try {
      final db = ref.read(databaseProvider);
      await InitialDataSeeder.cleanDummyData(db);
      await InitialDataSeeder.seedDatabase(db);
    } catch (_) {}

    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;

    setState(() {
      _statusMessage = 'Prepping media isolates & POS registers...';
      _progressValue = 0.75;
    });

    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    setState(() {
      _statusMessage = 'Ready!';
      _progressValue = 1.0;
    });

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    _navigateToNextScreen();
  }

  void _navigateToNextScreen() {
    final isAuthenticated = ref.read(authProvider).isAuthenticated;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            isAuthenticated ? const KioskWorkstationHome() : const AuthScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 450),
      ),
    );
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    _logoController.dispose();
    _pulseController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.2),
            radius: 1.2,
            colors: isDark
                ? [
                    const Color(0xFF1E1B4B), // Deep indigo
                    const Color(0xFF0F172A), // Slate 900
                    const Color(0xFF090D16), // Dark background
                  ]
                : [
                    const Color(0xFFEEF2FF), // Indigo 50
                    const Color(0xFFF1F5F9), // Slate 100
                    const Color(0xFFE2E8F0),
                  ],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // Animated Logo with Pulsing Glow
              AnimatedBuilder(
                animation: Listenable.merge([_logoController, _pulseController]),
                builder: (context, child) {
                  return Opacity(
                    opacity: _logoOpacity.value,
                    child: Transform.scale(
                      scale: _logoScale.value,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Ambient Pulse Ring
                          Transform.scale(
                            scale: _pulseScale.value,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.2 : 0.15),
                              ),
                            ),
                          ),
                          // Core Icon Container
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4F46E5), Color(0xFF7C3AED), Color(0xFF9333EA)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.folder_shared_rounded,
                                size: 44,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 32),

              // Animated Title and Subtitle
              SlideTransition(
                position: _textSlide,
                child: FadeTransition(
                  opacity: _textOpacity,
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'DOSSIER',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 4,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.4)),
                            ),
                            child: const Text(
                              'v1.0',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF818CF8),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Offline-First CRM & Kiosk Vault',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(flex: 2),

              // Animated Progress & Status Bar
              FadeTransition(
                opacity: _textOpacity,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                          tween: Tween<double>(begin: 0, end: _progressValue),
                          builder: (context, value, _) {
                            return LinearProgressIndicator(
                              value: value,
                              minHeight: 5,
                              backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          _statusMessage,
                          key: ValueKey<String>(_statusMessage),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
