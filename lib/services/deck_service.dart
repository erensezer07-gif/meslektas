import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/deck_profile.dart';

/// Deste erişim katmanı. Sıralama istemcide hesaplanmaz;
/// veritabanındaki get_deck() fonksiyonu çağrılır.
class DeckService {
  DeckService(this._client);

  final SupabaseClient _client;

  /// Puan sırasına göre aday profilleri getirir.
  Future<List<DeckProfile>> getDeck({int limit = 20}) async {
    final rows =
        await _client.rpc('get_deck', params: {'p_limit': limit}) as List;
    return rows
        .map((row) => DeckProfile.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Hata nesnesini kullanıcıya gösterilecek Türkçe mesaja çevirir.
  static String errorMessage(Object error) {
    if (error is PostgrestException) {
      return 'Deste yüklenemedi. Lütfen tekrar dene.';
    }
    return 'Bağlantı kurulamadı. İnternet bağlantını kontrol et.';
  }
}
