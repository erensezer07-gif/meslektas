import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/app_theme.dart';

/// E-posta alanı doğrulayıcısı (tüm auth formlarında ortak)
String? validateEmail(String? value) {
  if (value == null || value.trim().isEmpty) return 'E-posta adresini gir.';
  final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  if (!emailRegex.hasMatch(value.trim())) {
    return 'Geçerli bir e-posta adresi gir.';
  }
  return null;
}

/// Sunucu hatası kutusu: form altında, alan hatalarıyla aynı dilde
class ServerErrorBox extends StatelessWidget {
  const ServerErrorBox({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.errorSurface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.error,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: AppDurations.fast);
  }
}

/// Buton içi yükleme göstergesi (ekran ortasında spinner kuralı gereği
/// yükleme butonun içinde gösterilir)
class ButtonProgress extends StatelessWidget {
  const ButtonProgress({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: AppColors.textTertiary,
      ),
    );
  }
}
