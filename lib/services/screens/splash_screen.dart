import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme.dart';
import '../app_state.dart';
import 'widgets/syncstay_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _waitAndNavigate();
  }

  Future<void> _waitAndNavigate() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    final state = Provider.of<AppState>(context, listen: false);
    while (state.isLoading && mounted) {
      await Future.delayed(const Duration(milliseconds: 200));
    }

    if (!mounted) return;
    _goToLogin();
  }

  void _goToLogin() {
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final isDark = state.isDarkMode;
        final bg = isDark ? AppColors.darkBackground : AppColors.background;
        final titleColor = isDark ? Colors.white : AppColors.onSurface;
        final subtitleColor = isDark ? Colors.white70 : AppColors.onSurfaceVariant;

        return Scaffold(
          backgroundColor: bg,
          body: Stack(
            children: [
              Positioned(
                top: -120,
                right: -80,
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.18),
                  ),
                ),
              ),
              Positioned(
                bottom: -100,
                left: -60,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.secondary.withValues(alpha: isDark ? 0.1 : 0.22),
                  ),
                ),
              ),
              Positioned(
                top: 120,
                left: -40,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.tertiary.withValues(alpha: isDark ? 0.08 : 0.2),
                  ),
                ),
              ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FadeInDown(
                      duration: const Duration(milliseconds: 800),
                      child: const SyncStayLogo(size: 120, borderRadius: 30),
                    ),
                    const SizedBox(height: 28),
                    FadeInUp(
                      delay: const Duration(milliseconds: 300),
                      duration: const Duration(milliseconds: 700),
                      child: Text(
                        'SyncStay',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 42,
                          fontWeight: FontWeight.w800,
                          color: titleColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    FadeInUp(
                      delay: const Duration(milliseconds: 500),
                      duration: const Duration(milliseconds: 700),
                      child: Text(
                        state.isLoading
                            ? 'Connecting to Firebase...'
                            : 'Rooms • Mates • Skills',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          color: subtitleColor,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),
                    if (state.isLoading)
                      FadeIn(
                        delay: const Duration(milliseconds: 900),
                        duration: const Duration(milliseconds: 600),
                        child: const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      ),
                    if (state.initError != null && !state.isLoading) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          'Firebase connection issue — you can still try to login.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            color: AppColors.tertiary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: _goToLogin,
                        child: const Text('Continue to Login'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
