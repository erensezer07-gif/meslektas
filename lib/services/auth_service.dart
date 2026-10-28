import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase Auth üzerine ince katman.
/// Ekranlar Supabase'e doğrudan dokunmaz; hata mesajları
/// burada Türkçeye çevrilir, ekranlar ham hata göstermez.
class AuthService {
  AuthService(this._client);

  final SupabaseClient _client;

  /// Aktif oturum (yoksa null)
  Session? get currentSession => _client.auth.currentSession;

  /// E-posta + şifre ile kayıt.
  /// Not: E-posta doğrulaması Supabase panelinden kapatıldığı için
  /// başarılı kayıt sonrası kullanıcı doğrudan giriş yapmış olur.
  Future<void> signUp({required String email, required String password}) async {
    await _client.auth.signUp(email: email, password: password);
  }

  /// E-posta + şifre ile giriş.
  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  /// Şifre sıfırlama e-postası gönderir.
  /// TODO(v-sonrası): Bağlantıya tıklandıktan sonraki "yeni şifre belirleme"
  /// ekranı MVP kapsamı dışında bırakıldı; deep link + update ekranı
  /// eklendiğinde burada redirectTo parametresi ayarlanacak.
  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  /// Oturumu kapatır.
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Hata nesnesini kullanıcıya gösterilecek Türkçe mesaja çevirir.
  static String errorMessage(Object error) {
    if (error is AuthException) {
      switch (error.code) {
        case 'invalid_credentials':
          return 'E-posta veya şifre hatalı.';
        case 'user_already_exists':
        case 'email_exists':
          return 'Bu e-posta adresi zaten kayıtlı.';
        case 'weak_password':
          return 'Şifre çok zayıf; en az 6 karakter kullan.';
        case 'email_not_confirmed':
          return 'E-posta adresin henüz doğrulanmamış. '
              'Gelen kutundaki doğrulama bağlantısına tıkla.';
        case 'over_email_send_rate_limit':
        case 'over_request_rate_limit':
          return 'Çok fazla deneme yapıldı. Lütfen biraz bekleyip tekrar dene.';
        case 'validation_failed':
          return 'Geçerli bir e-posta adresi gir.';
      }
      // Kod eşleşmezse mesaj içeriğinden yakala
      final msg = error.message.toLowerCase();
      if (msg.contains('email not confirmed')) {
        return 'E-posta adresin henüz doğrulanmamış. '
            'Gelen kutundaki doğrulama bağlantısına tıkla.';
      }
      if (msg.contains('invalid login credentials')) {
        return 'E-posta veya şifre hatalı.';
      }
      return 'İşlem başarısız oldu. Lütfen tekrar dene.';
    }
    // Ağ ve diğer beklenmeyen hatalar
    return 'Bağlantı kurulamadı. İnternet bağlantını kontrol et.';
  }
}
