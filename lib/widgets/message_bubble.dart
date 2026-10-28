import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Sohbet mesaj balonu (WhatsApp sadeliği): kendi mesajın sağda
/// vurgu yüzeyiyle, karşı tarafınki solda hafif dolguyla.
class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.text, required this.isMine});

  final String text;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: isMine ? AppColors.primarySurface : AppColors.surfaceSubtle,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppRadius.md),
            topRight: const Radius.circular(AppRadius.md),
            bottomLeft: Radius.circular(isMine ? AppRadius.md : AppRadius.sm),
            bottomRight: Radius.circular(isMine ? AppRadius.sm : AppRadius.md),
          ),
        ),
        child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
      ),
    );
  }
}
