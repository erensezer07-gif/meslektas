import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/message.dart';

/// Sohbet erişim katmanı. Mesajlar Realtime akışıyla dinlenir
/// (messages tablosu supabase_realtime yayınına ekli); karşı taraf
/// yazdığı anda akışa düşer, ayrıca yenileme gerekmez.
class ChatService {
  ChatService(this._client);

  final SupabaseClient _client;

  /// Eşleşmenin mesajları: geçmiş + canlı güncellemeler tek akışta,
  /// eskiden yeniye sıralı.
  Stream<List<Message>> messagesStream(int matchId) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('match_id', matchId)
        .order('created_at', ascending: true)
        .map((rows) => rows.map(Message.fromJson).toList());
  }

  /// Mesaj gönderir. RLS yalnızca eşleşmenin tarafına izin verir.
  Future<void> send({required int matchId, required String content}) async {
    await _client.from('messages').insert({
      'match_id': matchId,
      'sender_id': _client.auth.currentUser!.id,
      'content': content.trim(),
    });
  }

  /// Hata nesnesini kullanıcıya gösterilecek Türkçe mesaja çevirir.
  static String errorMessage(Object error) {
    if (error is PostgrestException) {
      return 'Mesaj gönderilemedi. Lütfen tekrar dene.';
    }
    return 'Bağlantı kurulamadı. İnternet bağlantını kontrol et.';
  }
}
