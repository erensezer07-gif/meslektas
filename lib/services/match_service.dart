import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/match.dart';

/// Eşleşme listesi erişim katmanı. RLS yalnızca tarafı olduğun
/// eşleşmeleri döndürür; ek filtre gerekmez.
class MatchService {
  MatchService(this._client);

  final SupabaseClient _client;

  /// Eşleşmeleri karşı taraf profilleriyle birlikte, yeniden eskiye getirir.
  Future<List<Match>> getMatches() async {
    final userId = _client.auth.currentUser!.id;
    final rows = await _client
        .from('matches')
        .select(
          'id, created_at, '
          'user1:profiles!matches_user1_id_fkey(id, full_name, title, avatar_url), '
          'user2:profiles!matches_user2_id_fkey(id, full_name, title, avatar_url)',
        )
        .order('created_at', ascending: false);
    return rows.map((row) => Match.fromJson(row, userId)).toList();
  }

  /// Hata nesnesini kullanıcıya gösterilecek Türkçe mesaja çevirir.
  static String errorMessage(Object error) {
    if (error is PostgrestException) {
      return 'Eşleşmeler yüklenemedi. Lütfen tekrar dene.';
    }
    return 'Bağlantı kurulamadı. İnternet bağlantını kontrol et.';
  }
}
