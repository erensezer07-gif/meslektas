import 'package:flutter/material.dart';

import '../constants/tags.dart';
import '../models/deck_profile.dart';
import '../theme/app_theme.dart';

/// Destede gösterilen profil kartı (referans: Tinder kart düzeni,
/// LinkedIn içerik ciddiyeti). Üstte fotoğraf, altta kimlik ve
/// yetkinlik chip'leri; ince kenarlık, ağır gölge yok.
class ProfileCard extends StatelessWidget {
  const ProfileCard({
    super.key,
    required this.profile,
    this.myLookingFor = const {},
  });

  final DeckProfile profile;

  /// Benim arayış etiketlerim (veritabanı formunda). Karşı tarafın
  /// bunlarla örtüşen yetkinlikleri vurgulanır ("eşleşme nedeni").
  final Set<String> myLookingFor;

  /// Kartta en fazla bu kadar chip gösterilir; fazlası "+n" olur.
  static const _maxChips = 5;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // Örtüşenler öne: chip sınırında kaybolmasınlar
    final matched = profile.skills.where(myLookingFor.contains).toList();
    final others = profile.skills
        .where((s) => !myLookingFor.contains(s))
        .toList();
    final shownSkills = [...matched, ...others].take(_maxChips).toList();
    final hiddenCount = profile.skills.length - shownSkills.length;
    // Birebir eşleşme yoksa kategori düzeyinde ortaklık ara: deste puanı
    // da (get_deck) aynı kategori mantığıyla puan verdiği için kartın
    // "neden karşımda?" sorusuna cevabı sıralamayla tutarlı olur.
    String? sharedCategory;
    if (matched.isEmpty) {
      final seekCategories = myLookingFor
          .map(tagCategory)
          .whereType<String>()
          .toSet();
      for (final skill in profile.skills) {
        final category = tagCategory(skill);
        if (category != null && seekCategories.contains(category)) {
          sharedCategory = category;
          break;
        }
      }
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Fotoğraf: kartın üst yarısından fazlasını kaplar
          Expanded(
            flex: 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                profile.avatarUrl == null
                    ? const ColoredBox(
                        color: AppColors.surfaceSubtle,
                        child: Center(
                          child: Icon(
                            Icons.person_outline_rounded,
                            size: 64,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      )
                    : Image.network(
                        profile.avatarUrl!,
                        fit: BoxFit.cover,
                        // Ağ hatasında boş gri yüzeye düş
                        errorBuilder: (_, _, _) => const ColoredBox(
                          color: AppColors.surfaceSubtle,
                          child: Center(
                            child: Icon(
                              Icons.person_outline_rounded,
                              size: 64,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ),
                        loadingBuilder: (_, child, progress) => progress == null
                            ? child
                            : const ColoredBox(color: AppColors.surfaceSubtle),
                      ),
                // Eşleşme nedeni rozeti: aradığın etiket bu profilde var;
                // birebir yoksa aynı kategoriden yetkinlik vurgulanır.
                if (matched.isNotEmpty || sharedCategory != null)
                  Positioned(
                    left: AppSpacing.md,
                    right: AppSpacing.md,
                    bottom: AppSpacing.md,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: matched.isNotEmpty
                              ? AppColors.primary
                              : AppColors.primarySurface,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Text(
                          matched.isNotEmpty
                              ? (matched.length == 1
                                    ? 'Aradığın: ${displayTag(matched.first)}'
                                    : 'Aradığın: ${displayTag(matched.first)} '
                                          '+${matched.length - 1}')
                              : 'Aradığın alandan: $sharedCategory',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: matched.isNotEmpty
                                ? Colors.white
                                : AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Kimlik ve etiketler
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.fullName,
                    style: textTheme.titleLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (profile.title != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      profile.title!,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (profile.city != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(profile.city!, style: textTheme.bodySmall),
                      ],
                    ),
                  ],
                  const Spacer(),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final skill in shownSkills)
                        _SkillChip(
                          label: displayTag(skill),
                          matched: myLookingFor.contains(skill),
                        ),
                      if (hiddenCount > 0)
                        _SkillChip(label: '+$hiddenCount', subtle: true),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kart içi kompakt yetkinlik chip'i (seçilemez, yalnızca gösterim).
/// matched: benim arayışımla örtüşüyor — dolu vurgu rengiyle öne çıkar.
class _SkillChip extends StatelessWidget {
  const _SkillChip({
    required this.label,
    this.subtle = false,
    this.matched = false,
  });

  final String label;
  final bool subtle;
  final bool matched;

  @override
  Widget build(BuildContext context) {
    final background = matched
        ? AppColors.primary
        : subtle
        ? AppColors.surfaceSubtle
        : AppColors.primarySurface;
    final foreground = matched
        ? Colors.white
        : subtle
        ? AppColors.textSecondary
        : AppColors.primary;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
