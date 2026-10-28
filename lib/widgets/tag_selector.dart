import 'package:flutter/material.dart';

import '../constants/tags.dart';
import '../theme/app_theme.dart';

/// Kategorili, aranabilir etiket seçici. Onboarding ve profil
/// düzenleme ortak kullanır.
class TagSelector extends StatefulWidget {
  const TagSelector({
    super.key,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
  });

  final String title;
  final String subtitle;

  /// Seçim durumu dışarıda yaşar; widget bu kümeyi doğrudan günceller.
  final Set<String> selected;
  final VoidCallback onChanged;
  final bool enabled;

  @override
  State<TagSelector> createState() => _TagSelectorState();
}

class _TagSelectorState extends State<TagSelector> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // Türkçe duyarlı, ı/i bağışlayıcı arama karşılaştırması
    final query = searchFold(_query.trim());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.title, style: textTheme.titleLarge),
        const SizedBox(height: AppSpacing.xs),
        Text(widget.subtitle, style: textTheme.bodySmall),
        const SizedBox(height: AppSpacing.md),
        TextField(
          enabled: widget.enabled,
          decoration: InputDecoration(
            hintText: 'Etiket ara',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            isDense: true,
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () => setState(() => _query = ''),
                  ),
          ),
          onChanged: (value) => setState(() => _query = value),
          // Arama kutusu form değil; controller yerine state yeter
        ),
        if (widget.selected.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final tag in widget.selected)
                InputChip(
                  label: Text(tag),
                  backgroundColor: AppColors.primarySurface,
                  deleteIconColor: AppColors.primary,
                  onDeleted: widget.enabled
                      ? () {
                          setState(() => widget.selected.remove(tag));
                          widget.onChanged();
                        }
                      : null,
                ),
            ],
          ),
        ],
        for (final category in tagCategories) ...[
          if (_visibleTags(category, query).isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(category.name, style: textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final tag in _visibleTags(category, query))
                  FilterChip(
                    label: Text(tag),
                    selected: widget.selected.contains(tag),
                    showCheckmark: false,
                    onSelected: widget.enabled
                        ? (isSelected) {
                            setState(() {
                              isSelected
                                  ? widget.selected.add(tag)
                                  : widget.selected.remove(tag);
                            });
                            widget.onChanged();
                          }
                        : null,
                  ),
              ],
            ),
            if (query.isEmpty && category.hiddenCount > 0) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                '+${category.hiddenCount} etiket daha — arama kutusuna yazarak bul',
                style: textTheme.bodySmall,
              ),
            ],
          ],
        ],
      ],
    );
  }

  /// Arama boşken yalnızca öne çıkan etiketler gösterilir; kalanı
  /// (yüzlerce etiket) arayüzü boğmamak için arama ile bulunur.
  List<String> _visibleTags(TagCategory category, String query) {
    if (query.isEmpty) {
      return category.tags.take(category.featuredCount).toList();
    }
    return category.tags.where((t) => searchFold(t).contains(query)).toList();
  }
}
