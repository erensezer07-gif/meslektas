import 'package:supabase_flutter/supabase_flutter.dart';

/// Kaydırma erişim katmanı. Eşleşme istemciden asla insert edilmez;
/// karşılıklı beğenide sunucudaki trigger oluşturur (docs/schema.sql §4).
class SwipeService {
  SwipeService(this._client);

  final SupabaseClient _client;

  /// Kararı swipes tablosuna yazar. Karşılıklı beğeniyle eşleşme
  /// oluştuysa eşleşme id'sini döner (trigger senkron çalıştığı için
  /// insert dönünce eşleşme satırı hazırdır); yoksa null.
  Future<int?> swipe({required String swipedId, required bool isLike}) async {
    final userId = _client.auth.currentUser!.id;

    try {
      await _client.from('swipes').insert({
        'swiper_id': userId,
        'swiped_id': swipedId,
        'is_like': isLike,
      });
    } on PostgrestException catch (e) {
      // 23505: aynı kişiye ikinci swipe (unique kısıtı). Kayıt zaten
      // var demektir; akışı bozma, eşleşme kontrolüne devam et.
      if (e.code != '23505') rethrow;
    }

    if (!isLike) return null;
    return _matchId(userId, swipedId);
  }

  /// Son kaydırmayı geri alır (swipes satırını siler). Eşleşme oluşmuş
  /// kaydırmayı RLS politikası sildirmez (docs/schema.sql §2); o durumda
  /// hiçbir satır silinmez ve false döner.
  Future<bool> undoSwipe({required String swipedId}) async {
    final userId = _client.auth.currentUser!.id;
    final deleted = await _client
        .from('swipes')
        .delete()
        .eq('swiper_id', userId)
        .eq('swiped_id', swipedId)
        .select('swiped_id');
    return deleted.isNotEmpty;
  }

  /// Bu çift için eşleşme satırı var mı? matches tablosunda çift
  /// user1_id < user2_id sıralı tutulur; uuid'lerin küçük harfli hex
  /// metin sırası Postgres'in uuid sırasıyla aynıdır.
  Future<int?> _matchId(String a, String b) async {
    final user1 = a.compareTo(b) < 0 ? a : b;
    final user2 = a.compareTo(b) < 0 ? b : a;
    final row = await _client
        .from('matches')
        .select('id')
        .eq('user1_id', user1)
        .eq('user2_id', user2)
        .maybeSingle();
    return row == null ? null : row['id'] as int;
  }

  /// Hata nesnesini kullanıcıya gösterilecek Türkçe mesaja çevirir.
  static String errorMessage(Object error) {
    if (error is PostgrestException) {
      return 'Karar kaydedilemedi. Lütfen tekrar dene.';
    }
    return 'Bağlantı kurulamadı. İnternet bağlantını kontrol et.';
  }
}
