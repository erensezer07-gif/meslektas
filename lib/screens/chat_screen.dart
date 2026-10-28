import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart';
import '../models/match.dart';
import '../models/message.dart';
import '../services/chat_service.dart';
import '../services/profile_service.dart';
import '../theme/app_theme.dart';
import '../widgets/message_bubble.dart';
import 'profile_view_screen.dart';

/// Sohbet ekranı (docs/mvp.md §4.6): yalnızca eşleşen iki kullanıcı
/// arasında, yalnızca yazılı, Realtime — mesaj yazıldığı anda karşı
/// tarafta belirir. Referans: WhatsApp sadeliği.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.matchId, required this.other});

  final int matchId;
  final MatchProfile other;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  late final Stream<List<Message>> _messages;

  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _messages = ChatService(supabase).messagesStream(widget.matchId);
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Karşı tarafın CV'sini imzalı URL ile açar (eşleşme sonrası
  /// erişim kuralı RLS'te; eşleşmemiş biri URL üretemez).
  Future<void> _viewCv() async {
    try {
      final cvPath = await ProfileService(
        supabase,
      ).getCvPathOf(widget.other.id);
      if (!mounted) return;
      if (cvPath == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.other.fullName} henüz CV yüklememiş.'),
          ),
        );
        return;
      }
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

  Future<void> _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      await ChatService(supabase).send(matchId: widget.matchId, content: text);
      _inputController.clear();
    } catch (e) {
      if (mounted) {
        // Metin kutuda kalır; kullanıcı tekrar deneyebilir
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(ChatService.errorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        // Başlığa (avatar + ad) dokununca karşı tarafın profili açılır
        title: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProfileViewScreen(
                userId: widget.other.id,
                fallbackName: widget.other.fullName,
              ),
            ),
          ),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border),
                  image: widget.other.avatarUrl == null
                      ? null
                      : DecorationImage(
                          image: NetworkImage(widget.other.avatarUrl!),
                          fit: BoxFit.cover,
                        ),
                ),
                child: widget.other.avatarUrl == null
                    ? const Icon(
                        Icons.person_outline_rounded,
                        size: 20,
                        color: AppColors.textTertiary,
                      )
                    : null,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.other.fullName,
                      style: textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.other.title != null)
                      Text(
                        widget.other.title!,
                        style: textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            onPressed: _viewCv,
            tooltip: 'CV\'yi görüntüle',
            icon: const Icon(Icons.description_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                Expanded(
                  child: StreamBuilder<List<Message>>(
                    stream: _messages,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return _buildError();
                      }
                      if (!snapshot.hasData) {
                        return _buildLoading();
                      }
                      final messages = snapshot.data!;
                      if (messages.isEmpty) {
                        return _buildEmpty();
                      }
                      final myId = supabase.auth.currentUser!.id;
                      // reverse liste: en yeni mesaj altta, klavye açılınca
                      // görünür kalır
                      return ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[messages.length - 1 - index];
                          return MessageBubble(
                            text: message.content,
                            isMine: message.senderId == myId,
                          );
                        },
                      );
                    },
                  ),
                ),
                _buildInputBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              enabled: !_sending,
              minLines: 1,
              maxLines: 4,
              maxLength: 2000,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: const InputDecoration(
                hintText: 'Mesaj yaz',
                isDense: true,
                counterText: '', // karakter sayacı gizli (sınır DB'de de var)
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton(
            onPressed: _sending ? null : _send,
            tooltip: 'Gönder',
            style: IconButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.surfaceSubtle,
              disabledForegroundColor: AppColors.textTertiary,
              padding: const EdgeInsets.all(AppSpacing.md),
            ),
            icon: const Icon(Icons.send_rounded, size: 20),
          ),
        ],
      ),
    );
  }

  /// Yükleme: balon biçiminde shimmer iskelet (spinner yok)
  Widget _buildLoading() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Shimmer.fromColors(
        baseColor: AppColors.surfaceSubtle,
        highlightColor: AppColors.background,
        child: Column(
          children: [
            for (final (width, mine) in const [
              (200.0, false),
              (240.0, true),
              (160.0, false),
              (180.0, true),
            ])
              Align(
                alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  width: width,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.chat_bubble_outline_rounded,
            size: 32,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Henüz mesaj yok', style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text('İlk mesajı sen gönderebilirsin.', style: textTheme.bodySmall),
        ],
      ).animate().fadeIn(duration: AppDurations.normal),
    );
  }

  Widget _buildError() {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 32, color: AppColors.error),
          const SizedBox(height: AppSpacing.md),
          Text('Mesajlar yüklenemedi', style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'İnternet bağlantını kontrol edip ekranı yeniden aç.',
            style: textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
