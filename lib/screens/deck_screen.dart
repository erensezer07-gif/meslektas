import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';

import '../main.dart';
import '../models/deck_profile.dart';
import '../models/match.dart';
import '../services/auth_service.dart';
import '../services/deck_service.dart';
import '../services/profile_service.dart';
import '../services/swipe_service.dart';
import '../theme/app_theme.dart';
import '../widgets/profile_card.dart';
import 'chat_screen.dart';
import 'login_screen.dart';
import 'matches_screen.dart';
import 'profile_edit_screen.dart';
import 'profile_view_screen.dart';

/// Ana ekran: deste (docs/mvp.md §4.4-4.5). Profiller get_deck() puan
/// sırasıyla gelir; kart sürüklemeyi takip eder, yönüne göre döner.
/// Karar swipes tablosuna yazılır; karşılıklı beğenide sunucu trigger'ı
/// eşleşmeyi oluşturur ve "Eşleştiniz!" diyaloğu gösterilir.
class DeckScreen extends StatefulWidget {
  const DeckScreen({super.key});

  @override
  State<DeckScreen> createState() => _DeckScreenState();
}

class _DeckScreenState extends State<DeckScreen>
    with SingleTickerProviderStateMixin {
  final List<DeckProfile> _deck = [];

  /// Benim arayışlarım (veritabanı formunda) — kartlarda örtüşen
  /// yetkinliklerin vurgulanması için
  Set<String> _myLookingFor = {};
  bool _loading = true;
  String? _error;

  /// Geri alınabilecek son kaydırma (tek adım). Eşleşme oluştuysa veya
  /// yazma başarısız olduysa temizlenir.
  DeckProfile? _lastSwiped;

  /// Üst kartın anlık sürükleme konumu
  Offset _drag = Offset.zero;
  bool _dragging = false;

  late final AnimationController _controller;
  Animation<Offset>? _release;
  bool? _pendingLike; // animasyon bitince işlenecek karar (null: geri oturma)

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: AppDurations.normal)
          ..addListener(() {
            if (_release != null) setState(() => _drag = _release!.value);
          })
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) _onReleaseEnd();
          });
    _loadDeck();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadDeck() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Deste ve kendi arayışlarım paralel çekilir
      final (profiles, myLookingFor) = await (
        DeckService(supabase).getDeck(),
        ProfileService(supabase).getMyLookingFor(),
      ).wait;
      if (!mounted) return;
      setState(() {
        _deck
          ..clear()
          ..addAll(profiles);
        _myLookingFor = myLookingFor;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = DeckService.errorMessage(e);
        });
      }
    }
  }

  // ---------- Kaydırma fiziği ----------

  /// Kartın uçmuş sayılacağı yatay eşik (ekran genişliğine oranla)
  double _threshold(Size size) => size.width * 0.28;

  void _onPanStart(DragStartDetails _) {
    if (_controller.isAnimating) return;
    _dragging = true;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_dragging) return;
    setState(() => _drag += details.delta);
  }

  void _onPanEnd(DragEndDetails details, Size size) {
    if (!_dragging) return;
    _dragging = false;
    final passedThreshold = _drag.dx.abs() > _threshold(size);
    final flung = details.velocity.pixelsPerSecond.dx.abs() > 900;
    if (passedThreshold || flung) {
      final right = passedThreshold
          ? _drag.dx > 0
          : details.velocity.pixelsPerSecond.dx > 0;
      _flyOut(like: right, size: size);
    } else {
      _springBack();
    }
  }

  /// Kart eşiği geçti: ekran dışına uçur, sonra kararı işle
  void _flyOut({required bool like, required Size size}) {
    _pendingLike = like;
    final target = Offset(
      (like ? 1 : -1) * size.width * 1.4,
      _drag.dy + (_drag.dy.sign * 40),
    );
    _release = Tween(
      begin: _drag,
      end: target,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutQuad));
    _controller
      ..duration = AppDurations.normal
      ..forward(from: 0);
  }

  /// Eşik geçilmedi: kart yayla yerine otursun
  void _springBack() {
    _pendingLike = null;
    _release = Tween(
      begin: _drag,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _controller
      ..duration = AppDurations.normal
      ..forward(from: 0);
  }

  void _onReleaseEnd() {
    final like = _pendingLike;
    _release = null;
    _pendingLike = null;
    if (like == null) {
      // geri oturdu; sürükleme sıfırlandı
      setState(() => _drag = Offset.zero);
      return;
    }
    if (_deck.isEmpty) return;
    final profile = _deck.first;
    setState(() {
      _deck.removeAt(0);
      _drag = Offset.zero;
      _lastSwiped = profile;
    });
    // Kart akıcı düşsün diye yazma arka planda yapılır
    _persistSwipe(profile, like);
  }

  /// Kararı veritabanına yazar; eşleşme oluştuysa diyalog gösterir.
  /// Yazma başarısız olursa kart desteye geri konur.
  Future<void> _persistSwipe(DeckProfile profile, bool like) async {
    try {
      final matchId = await SwipeService(
        supabase,
      ).swipe(swipedId: profile.id, isLike: like);
      if (matchId != null && mounted) {
        // Eşleşme oluştu: geri alma artık mümkün değil (RLS de engeller)
        setState(() => _lastSwiped = null);
        _showMatchDialog(profile, matchId);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _deck.insert(0, profile);
        // Kart zaten geri geldi; geri alınacak bir şey kalmadı
        if (_lastSwiped?.id == profile.id) _lastSwiped = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(SwipeService.errorMessage(e))));
    }
  }

  /// Son kaydırmayı geri alır: kayıt silinir, kart destenin üstüne döner.
  Future<void> _undoLastSwipe() async {
    final profile = _lastSwiped;
    if (profile == null || _controller.isAnimating) return;
    // Çifte dokunmayı engelle
    setState(() => _lastSwiped = null);
    try {
      final undone = await SwipeService(
        supabase,
      ).undoSwipe(swipedId: profile.id);
      if (!mounted) return;
      if (undone) {
        setState(() => _deck.insert(0, profile));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bu kaydırma geri alınamıyor.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      // Başarısız oldu: buton yeniden denenebilsin
      setState(() => _lastSwiped = profile);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(SwipeService.errorMessage(e))));
    }
  }

  /// Üst karta dokununca tam profil açılır (CV eşleşme öncesi gizli)
  void _openProfile(DeckProfile profile) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileViewScreen(
          userId: profile.id,
          fallbackName: profile.fullName,
          showCv: false,
        ),
      ),
    );
  }

  void _showMatchDialog(DeckProfile profile, int matchId) {
    showDialog<void>(
      context: context,
      builder: (_) => _MatchDialog(profile: profile, matchId: matchId),
    );
  }

  /// Alt butonlar da aynı uçuş animasyonunu tetikler
  void _swipeByButton(bool like) {
    if (_controller.isAnimating || _deck.isEmpty) return;
    _flyOut(like: like, size: MediaQuery.of(context).size);
  }

  // ---------- Arayüz ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Eşleşme'),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const MatchesScreen())),
            tooltip: 'Eşleşmeler',
            icon: const Icon(Icons.forum_outlined),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileEditScreen()),
            ),
            tooltip: 'Profilim',
            icon: const Icon(Icons.person_outline_rounded),
          ),
          IconButton(
            onPressed: () async {
              await AuthService(supabase).signOut();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            tooltip: 'Çıkış yap',
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: _loading
                ? _buildLoading()
                : _error != null
                ? _buildError()
                : _deck.isEmpty
                ? _buildEmpty()
                : _buildDeck(),
          ),
        ),
      ),
    );
  }

  Widget _buildDeck() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final progress = (_drag.dx.abs() / _threshold(size)).clamp(0.0, 1.0);
        final rotation = _drag.dx / size.width * 0.25;

        return Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Alttaki kart: sürükleme ilerledikçe öne doğru büyür
                    if (_deck.length > 1)
                      Transform.scale(
                        scale: 0.95 + 0.05 * progress,
                        child: ProfileCard(
                          profile: _deck[1],
                          myLookingFor: _myLookingFor,
                        ),
                      ),
                    // Üst kart: parmağı takip eder, yönüne göre döner
                    Transform.translate(
                      offset: _drag,
                      child: Transform.rotate(
                        angle: rotation,
                        child: GestureDetector(
                          onTap: () => _openProfile(_deck.first),
                          onPanStart: _onPanStart,
                          onPanUpdate: _onPanUpdate,
                          onPanEnd: (d) => _onPanEnd(d, size),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ProfileCard(
                                profile: _deck.first,
                                myLookingFor: _myLookingFor,
                              ),
                              // Karar rozetleri: sürüklerken belirir
                              if (_drag.dx > 0)
                                _DecisionBadge(
                                  label: 'İlgileniyorum',
                                  color: AppColors.success,
                                  alignment: Alignment.topLeft,
                                  opacity: progress,
                                ),
                              if (_drag.dx < 0)
                                _DecisionBadge(
                                  label: 'Geç',
                                  color: AppColors.error,
                                  alignment: Alignment.topRight,
                                  opacity: progress,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xl),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ActionButton(
                    icon: Icons.replay_rounded,
                    color: AppColors.textSecondary,
                    tooltip: 'Geri al',
                    onPressed: _lastSwiped == null ? null : _undoLastSwipe,
                  ),
                  const SizedBox(width: AppSpacing.xxl),
                  _ActionButton(
                    icon: Icons.close_rounded,
                    color: AppColors.error,
                    tooltip: 'Geç',
                    onPressed: () => _swipeByButton(false),
                  ),
                  const SizedBox(width: AppSpacing.xxl),
                  _ActionButton(
                    icon: Icons.check_rounded,
                    color: AppColors.success,
                    tooltip: 'İlgileniyorum',
                    onPressed: () => _swipeByButton(true),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// Yükleme: kart biçiminde shimmer iskelet (spinner yok)
  Widget _buildLoading() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Shimmer.fromColors(
        baseColor: AppColors.surfaceSubtle,
        highlightColor: AppColors.background,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceSubtle,
            borderRadius: BorderRadius.circular(AppRadius.lg),
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
                Icons.done_all_rounded,
                color: AppColors.primary,
                size: 32,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Şimdilik bu kadar', style: textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Şu an gösterilecek yeni profil yok.\nDaha sonra tekrar bakabilirsin.',
              style: textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            OutlinedButton.icon(
              onPressed: _loadDeck,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Yenile'),
            ),
            // Son kart kaydırıldıysa buradan da geri alınabilsin
            if (_lastSwiped != null) ...[
              const SizedBox(height: AppSpacing.sm),
              TextButton.icon(
                onPressed: _undoLastSwipe,
                icon: const Icon(Icons.replay_rounded, size: 18),
                label: const Text('Son kaydırmayı geri al'),
              ),
            ],
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
            Text('Deste yüklenemedi', style: textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _error!,
              style: textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            OutlinedButton(
              onPressed: _loadDeck,
              child: const Text('Tekrar dene'),
            ),
          ],
        )
        .animate()
        .fadeIn(duration: AppDurations.normal)
        .slideY(begin: 0.1, end: 0, duration: AppDurations.normal);
  }
}

/// Karşılıklı beğeni diyaloğu. Ses tonu kuralı: profesyonel dil,
/// romantik/flört çağrışımı yok (tasarım kuralı).
class _MatchDialog extends StatelessWidget {
  const _MatchDialog({required this.profile, required this.matchId});

  final DeckProfile profile;
  final int matchId;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Dialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            side: const BorderSide(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 96,
                  height: 96,
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
                          size: 40,
                          color: AppColors.textTertiary,
                        )
                      : null,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Eşleştiniz!', style: textTheme.headlineMedium),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${profile.fullName} ile artık iletişim kurabilirsiniz.',
                  style: textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      // Diyalog kapanınca context ölür; navigator'ı önce al
                      final navigator = Navigator.of(context);
                      navigator.pop();
                      navigator.push(
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            matchId: matchId,
                            other: MatchProfile(
                              id: profile.id,
                              fullName: profile.fullName,
                              title: profile.title,
                              avatarUrl: profile.avatarUrl,
                            ),
                          ),
                        ),
                      );
                    },
                    child: const Text('Mesaj gönder'),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Devam et'),
                  ),
                ),
              ],
            ),
          ),
        )
        .animate()
        .fadeIn(duration: AppDurations.normal)
        .scale(
          begin: const Offset(0.9, 0.9),
          end: const Offset(1, 1),
          duration: AppDurations.normal,
          curve: Curves.easeOutBack,
        );
  }
}

/// Sürüklerken kartın köşesinde beliren karar rozeti
class _DecisionBadge extends StatelessWidget {
  const _DecisionBadge({
    required this.label,
    required this.color,
    required this.alignment,
    required this.opacity,
  });

  final String label;
  final Color color;
  final Alignment alignment;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Opacity(
          opacity: opacity,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: color, width: 2),
            ),
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: color),
            ),
          ),
        ),
      ),
    );
  }
}

/// Alt karar butonu: dairesel, ince kenarlıklı.
/// onPressed null ise devre dışı görünür (geri al butonu için).
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      iconSize: 32,
      style: IconButton.styleFrom(
        backgroundColor: AppColors.surface,
        foregroundColor: color,
        disabledForegroundColor: AppColors.textTertiary,
        disabledBackgroundColor: AppColors.surface,
        side: const BorderSide(color: AppColors.border),
        padding: const EdgeInsets.all(AppSpacing.lg),
      ),
      icon: Icon(icon),
    );
  }
}
