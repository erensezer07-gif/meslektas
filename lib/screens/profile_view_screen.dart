import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/tags.dart';
import '../main.dart';
import '../models/profile.dart';
import '../services/profile_service.dart';
import '../theme/app_theme.dart';

/// Bir kullanıcının profili (salt-okunur, LinkedIn derinliği):
/// fotoğraf, kimlik, bio, etiketler, opsiyonel alanlar, bağlantılar
/// ve CV. Eşleşme listesinden (avatara dokunarak), sohbet başlığından
/// ve deste kartına dokunarak açılır.
class ProfileViewScreen extends StatefulWidget {
  const ProfileViewScreen({
    super.key,
    required this.userId,
    this.fallbackName,
    this.showCv = true,
  });

  final String userId;

  /// Profil yüklenene kadar başlıkta gösterilecek ad
  final String? fallbackName;

  /// CV butonu gösterilsin mi? Desteden (eşleşme öncesi) açılan
  /// profilde false: CV yalnızca eşleşme sonrası görüntülenebilir
  /// (erişim kuralı zaten RLS'te; bu yalnızca arayüz tarafı).
  final bool showCv;

  @override
  State<ProfileViewScreen> createState() => _ProfileViewScreenState();
}

class _ProfileViewScreenState extends State<ProfileViewScreen> {
  Profile? _profile;

  /// Benim arayışlarım (veritabanı formunda) — örtüşen yetkinlikler
  /// ✓ işaretiyle vurgulanır
  Set<String> _myLookingFor = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _profile = null;
      _error = null;
    });
    try {
      // Karşı tarafın profili ve kendi arayışlarım paralel çekilir
      final (profile, myLookingFor) = await (
        ProfileService(supabase).getProfileOf(widget.userId),
        ProfileService(supabase).getMyLookingFor(),
      ).wait;
      if (mounted) {
        setState(() {
          _profile = profile;
          _myLookingFor = myLookingFor;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = ProfileService.errorMessage(e));
    }
  }

  Future<void> _viewCv() async {
    final cvPath = _profile?.cvPath;
    if (cvPath == null) return;
    try {
      // Erişim kuralı RLS'te: imzalı URL'i yalnızca sahibi ve
      // eşleştikleri üretebilir
      final url = await ProfileService(supabase).cvSignedUrl(cvPath);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CV açılamadı. Lütfen tekrar dene.')),
        );
      }
    }
  }

  Future<void> _openLink(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Bağlantı açılamadı.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_profile?.fullName ?? widget.fallbackName ?? 'Profil'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: _error != null
                ? _buildError()
                : _profile == null
                ? _buildLoading()
                : _buildProfile(),
          ),
        ),
      ),
    );
  }

  Widget _buildProfile() {
    final profile = _profile!;
    final textTheme = Theme.of(context).textTheme;
    // Örtüşen yetkinlikler öne sıralanır ve ✓ ile vurgulanır
    final matchedSkills = profile.skills
        .where(_myLookingFor.contains)
        .map(displayTag)
        .toList();
    final otherSkills = profile.skills
        .where((s) => !_myLookingFor.contains(s))
        .map(displayTag)
        .toList();
    final skills = [...matchedSkills, ...otherSkills];
    final lookingFor = profile.lookingFor.map(displayTag).toList();

    // Tek satırlık bilgi alanları: dolu olanlar listelenir
    final details = <(IconData, String, String)>[
      if (profile.experienceYears != null)
        (
          Icons.work_outline_rounded,
          'Deneyim',
          '${profile.experienceYears} yıl',
        ),
      if (profile.education != null)
        (Icons.school_outlined, 'Eğitim', profile.education!),
      if (profile.languages.isNotEmpty)
        (Icons.translate_rounded, 'Diller', profile.languages.join(', ')),
      if (profile.workPreference != null)
        (
          Icons.laptop_outlined,
          'Çalışma tercihi',
          _workPreferenceLabel(profile.workPreference!),
        ),
      if (profile.certificates.isNotEmpty)
        (
          Icons.verified_outlined,
          'Sertifikalar',
          profile.certificates.join(', '),
        ),
      if (profile.heightCm != null && profile.weightKg != null)
        (
          Icons.straighten_rounded,
          'Boy · Kilo',
          '${profile.heightCm} cm · ${profile.weightKg} kg',
        ),
    ];

    final links = <(IconData, String, String)>[
      if (profile.linkLinkedin != null)
        (Icons.business_center_outlined, 'LinkedIn', profile.linkLinkedin!),
      if (profile.linkGithub != null)
        (Icons.code_rounded, 'GitHub / Portfolyo', profile.linkGithub!),
      if (profile.linkWebsite != null)
        (Icons.language_rounded, 'Web sitesi', profile.linkWebsite!),
    ];

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        // Kimlik başlığı
        Center(
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: AppColors.surfaceSubtle,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
              image: profile.avatarUrl == null
                  ? null
                  : DecorationImage(
                      image: NetworkImage(profile.avatarUrl!),
                      fit: BoxFit.cover,
                    ),
            ),
            child: profile.avatarUrl == null
                ? const Icon(
                    Icons.person_outline_rounded,
                    size: 56,
                    color: AppColors.textTertiary,
                  )
                : null,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          profile.fullName,
          style: textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
        if (profile.title != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            profile.title!,
            style: textTheme.bodyLarge?.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        if (profile.city != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
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

        // CV (varsa) — yalnızca eşleşme sonrası görüntülenebilir
        if (widget.showCv && profile.cvPath != null) ...[
          const SizedBox(height: AppSpacing.xl),
          OutlinedButton.icon(
            onPressed: _viewCv,
            icon: const Icon(Icons.description_outlined, size: 18),
            label: const Text('CV\'yi görüntüle'),
          ),
        ],

        // Bio
        if (profile.bio != null) ...[
          const SizedBox(height: AppSpacing.xxl),
          Text('Hakkında', style: textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(profile.bio!, style: textTheme.bodyMedium),
        ],

        // Etiketler
        if (skills.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xxl),
          Text('Yetkinlikler', style: textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          _TagWrap(
            tags: skills,
            highlighted: true,
            matchedTags: matchedSkills.toSet(),
          ),
          if (matchedSkills.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'İşaretli yetkinlikler senin arayışlarınla örtüşüyor.',
              style: textTheme.bodySmall,
            ),
          ],
        ],
        if (lookingFor.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          Text('Arayışlar', style: textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          _TagWrap(tags: lookingFor, highlighted: false),
        ],

        // Detaylar
        if (details.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xxl),
          Text('Bilgiler', style: textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          for (final (icon, label, value) in details)
            _DetailRow(icon: icon, label: label, value: value),
        ],

        // Bağlantılar
        if (links.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xxl),
          Text('Bağlantılar', style: textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          for (final (icon, label, url) in links)
            _DetailRow(
              icon: icon,
              label: label,
              value: url,
              onTap: () => _openLink(url),
            ),
        ],
        const SizedBox(height: AppSpacing.xl),
      ],
    ).animate().fadeIn(duration: AppDurations.normal);
  }

  static String _workPreferenceLabel(String value) {
    return switch (value) {
      'yerinde' => 'Yerinde',
      'uzaktan' => 'Uzaktan',
      'hibrit' => 'Hibrit',
      _ => value,
    };
  }

  /// Yükleme: profil biçiminde shimmer iskelet (spinner yok)
  Widget _buildLoading() {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceSubtle,
      highlightColor: AppColors.background,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          Center(
            child: Container(
              width: 140,
              height: 140,
              decoration: const BoxDecoration(
                color: AppColors.surfaceSubtle,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final width in const [180.0, 120.0])
            Center(
              child: Container(
                width: width,
                height: 16,
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.xl),
          for (var i = 0; i < 3; i++)
            Container(
              height: 72,
              margin: const EdgeInsets.only(bottom: AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surfaceSubtle,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildError() {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Column(
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
          Text('Profil yüklenemedi', style: textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _error!,
            style: textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          OutlinedButton(
            onPressed: _loadProfile,
            child: const Text('Tekrar dene'),
          ),
        ],
      ),
    );
  }
}

/// Salt gösterim etiket kümesi. matchedTags içindekiler benim
/// arayışlarımla örtüşür: dolu vurgu rengi + ✓ işaretiyle gösterilir.
class _TagWrap extends StatelessWidget {
  const _TagWrap({
    required this.tags,
    required this.highlighted,
    this.matchedTags = const {},
  });

  final List<String> tags;
  final bool highlighted;
  final Set<String> matchedTags;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final tag in tags)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: matchedTags.contains(tag)
                  ? AppColors.primary
                  : highlighted
                  ? AppColors.primarySurface
                  : AppColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (matchedTags.contains(tag)) ...[
                  const Icon(
                    Icons.check_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                ],
                Text(
                  tag,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: matchedTags.contains(tag)
                        ? Colors.white
                        : highlighted
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// İkon + başlık + değer satırı; onTap verilirse dokunulabilir olur
class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: AppColors.textTertiary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: textTheme.bodySmall),
                  Text(
                    value,
                    style: textTheme.bodyMedium?.copyWith(
                      color: onTap != null
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(
                Icons.open_in_new_rounded,
                size: 16,
                color: AppColors.textTertiary,
              ),
          ],
        ),
      ),
    );
  }
}
