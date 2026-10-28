import 'package:flutter/material.dart';

import '../constants/cities.dart';
import '../constants/tags.dart';
import '../theme/app_theme.dart';

/// Şehir seçiciyi (arama kutulu bottom sheet, 81 il) açar;
/// seçilen ili, vazgeçilirse null döndürür.
Future<String?> showCityPicker(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (_) => const _CityPickerSheet(),
  );
}

class _CityPickerSheet extends StatefulWidget {
  const _CityPickerSheet();

  @override
  State<_CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends State<_CityPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    // Türkçe duyarlı, ı/i bağışlayıcı arama karşılaştırması
    final query = searchFold(_query.trim());
    final cities = query.isEmpty
        ? turkishCities
        : turkishCities.where((c) => searchFold(c).contains(query)).toList();

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Şehir ara',
                prefixIcon: Icon(Icons.search_rounded, size: 20),
                isDense: true,
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          const Divider(),
          Expanded(
            child: cities.isEmpty
                ? Center(
                    child: Text(
                      'Sonuç bulunamadı',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  )
                : ListView.builder(
                    itemCount: cities.length,
                    itemBuilder: (context, index) {
                      final city = cities[index];
                      return ListTile(
                        title: Text(city),
                        onTap: () => Navigator.of(context).pop(city),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
