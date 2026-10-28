import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';

import '../main.dart';
import '../models/match.dart';
import '../services/match_service.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';
import 'profile_view_screen.dart';

/// Eşleşme listesi (docs/mvp.md §4.5): karşılıklı beğeniyle oluşan
/// eşleşmeler, yeniden eskiye. Satıra dokununca sohbet açılır.
class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  List<Match>? _matches;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMatches();
  }

  Future<void> _loadMatches() async {
    setState(() {
      _matches = null;
      _error = null;
    });
    try {
      final matches = await MatchService(supabase).getMatches();
      if (mounted) setState(() => _matches = matches);
    } catch (e) {
      if (mounted) setState(() => _error = MatchService.errorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Eşleşmeler')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: _error != null
                ? _buildError()
                : _matches == null
                ? _buildLoading()
                : _matches!.isEmpty
                ? _buildEmpty()
                : _buildList(),
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    return RefreshIndicator(
      onRefresh: _loadMatches,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        itemCount: _matches!.length,
        separatorBuilder: (_, _) => const Divider(indent: 76),
        itemBuilder: (context, index) {
          final match = _matches![index];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xs,
            ),
            // Avatara dokununca profil, satırın kalanına dokununca sohbet
            leading: InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProfileViewScreen(
                    userId: match.other.id,
                    fallbackName: match.other.fullName,
                  ),
                ),
              ),
              customBorder: const CircleBorder(),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border),
                  image: match.other.avatarUrl == null
                      ? null
                      : DecorationImage(
                          image: NetworkImage(match.other.avatarUrl!),
                          fit: BoxFit.cover,
                        ),
                ),
                child: match.other.avatarUrl == null
                    ? const Icon(
                        Icons.person_outline_rounded,
                        color: AppColors.textTertiary,
                      )
                    : null,
              ),
            ),
            title: Text(
              match.other.fullName,
              style: Theme.of(context).textTheme.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: match.other.title == null
                ? null
                : Text(
                    match.other.title!,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textTertiary,
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    ChatScreen(matchId: match.id, other: match.other),
              ),
            ),
          ).animate().fadeIn(
            duration: AppDurations.normal,
            delay: Duration(milliseconds: 30 * index),
          );
        },
      ),
    );
  }

  /// Yükleme: satır biçiminde shimmer iskelet (spinner yok)
  Widget _buildLoading() {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceSubtle,
      highlightColor: AppColors.background,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: 6,
        itemBuilder: (_, _) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Container(
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    final textTheme = Theme.of(context).textTheme;
    return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: const BoxDecoration(
                color: AppColors.primarySurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.handshake_outlined,
                color: AppColors.primary,
                size: 32,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Henüz eşleşmen yok', style: textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Destedeki profilleri değerlendirmeye devam et;\n'
              'karşılıklı beğenide eşleşme burada görünür.',
              style: textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        )
        .animate()
        .fadeIn(duration: AppDurations.normal)
        .slideY(begin: 0.1, end: 0, duration: AppDurations.normal);
  }

  Widget _buildError() {
    final textTheme = Theme.of(context).textTheme;
    return Column(
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
            Text('Eşleşmeler yüklenemedi', style: textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _error!,
              style: textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            OutlinedButton(
              onPressed: _loadMatches,
              child: const Text('Tekrar dene'),
            ),
          ],
        )
        .animate()
        .fadeIn(duration: AppDurations.normal)
        .slideY(begin: 0.1, end: 0, duration: AppDurations.normal);
  }
}
