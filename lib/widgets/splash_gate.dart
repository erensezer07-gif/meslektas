import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';

import '../main.dart';
import '../screens/deck_screen.dart';
import '../screens/onboarding_screen.dart';
import '../services/profile_service.dart';
import '../theme/app_theme.dart';

/// Açılış kapısı: oturum sahibinin profili var mı diye bakar;
/// yoksa onboarding'e, varsa deste ekranına yönlendirir.
class SplashGate extends StatefulWidget {
  const SplashGate({super.key});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    setState(() => _error = false);
    try {
      final hasProfile = await ProfileService(supabase).hasProfile();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) =>
              hasProfile ? const DeckScreen() : const OnboardingScreen(),
        ),
        (route) => false,
      );
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: _error
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: const BoxDecoration(
                        color: AppColors.errorSurface,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.wifi_off_rounded,
                        color: AppColors.error,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text('Bağlantı kurulamadı', style: textTheme.titleLarge),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'İnternet bağlantını kontrol edip tekrar dene.',
                      style: textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    OutlinedButton(
                      onPressed: _route,
                      child: const Text('Tekrar dene'),
                    ),
                  ],
                ).animate().fadeIn(duration: AppDurations.normal)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Eşleşme', style: textTheme.headlineMedium),
                    const SizedBox(height: AppSpacing.lg),
                    Shimmer.fromColors(
                      baseColor: AppColors.surfaceSubtle,
                      highlightColor: AppColors.background,
                      child: Container(
                        width: 120,
                        height: 6,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
