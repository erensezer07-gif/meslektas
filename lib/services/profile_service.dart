import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/tags.dart';
import '../models/profile.dart';

/// Profil işlemleri için Supabase erişim katmanı.
/// Ekranlar Supabase'e doğrudan dokunmaz; hata mesajları
/// burada Türkçeye çevrilir.
class ProfileService {
  ProfileService(this._client);

  final SupabaseClient _client;

  /// Giriş yapan kullanıcının profili var mı?
  /// (Onboarding gösterilsin mi kararı için kullanılır.)
  Future<bool> hasProfile() async {
    final userId = _client.auth.currentUser!.id;
    final row = await _client
        .from('profiles')
        .select('id')
        .eq('id', userId)
        .maybeSingle();
    return row != null;
  }

  /// Onboarding sonunda profili kaydeder: önce fotoğrafı yükler,
  /// sonra profiles tablosuna yazar. Tekrar denemede sorun çıkmasın
  /// diye ikisi de üzerine yazar (upsert).
  Future<void> saveProfile({
    required String fullName,
    required String title,
    required String city,
    required List<String> skills,
    required List<String> lookingFor,
    required Uint8List avatarBytes,
  }) async {
    final userId = _client.auth.currentUser!.id;
    final avatarUrl = await _uploadAvatar(userId, avatarBytes);

    await _client.from('profiles').upsert({
      'id': userId,
      'full_name': fullName.trim(),
      'title': title.trim(),
      'city': city,
      // Etiketler veritabanında küçük harfle saklanır (docs/mvp.md §4.3);
      // çevirme yalnızca burada yapılır, ekran kodu görünen hali kullanır.
      'skills': skills.map(toDbTag).toList(),
      'looking_for': lookingFor.map(toDbTag).toList(),
      'avatar_url': avatarUrl,
    });
  }

  /// Fotoğrafı avatars deposuna `{uid}/avatar.jpg` yoluna yükler
  /// ve herkese açık URL'i döndürür.
  Future<String> _uploadAvatar(String userId, Uint8List bytes) async {
    final path = '$userId/avatar.jpg';
    await _client.storage
        .from('avatars')
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );
    final url = _client.storage.from('avatars').getPublicUrl(path);
    // Aynı yola tekrar yüklemede eski görselin önbellekte kalmaması için
    return '$url?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Giriş yapan kullanıcının tam profilini getirir.
  Future<Profile> getMyProfile() async {
    final userId = _client.auth.currentUser!.id;
    final row = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .single();
    return Profile.fromJson(row);
  }

  /// Profil düzenleme ekranındaki alanları günceller.
  /// Boş bırakılan opsiyonel alanlar null olarak yazılır (temizlenebilir).
  Future<void> updateProfile({
    required String fullName,
    required String title,
    required String city,
    required List<String> skills,
    required List<String> lookingFor,
    String? bio,
    int? heightCm,
    int? weightKg,
    int? experienceYears,
    String? education,
    required List<String> languages,
    String? linkLinkedin,
    String? linkGithub,
    String? linkWebsite,
    String? workPreference,
    required List<String> certificates,
  }) async {
    final userId = _client.auth.currentUser!.id;
    await _client
        .from('profiles')
        .update({
          'full_name': fullName.trim(),
          'title': title.trim(),
          'city': city,
          'skills': skills.map(toDbTag).toList(),
          'looking_for': lookingFor.map(toDbTag).toList(),
          'bio': bio,
          'height_cm': heightCm,
          'weight_kg': weightKg,
          'experience_years': experienceYears,
          'education': education,
          'languages': languages,
          'link_linkedin': linkLinkedin,
          'link_github': linkGithub,
          'link_website': linkWebsite,
          'work_preference': workPreference,
          'certificates': certificates,
        })
        .eq('id', userId);
  }

  /// Yeni profil fotoğrafı yükler ve profiles.avatar_url'i günceller;
  /// yeni URL'i döndürür.
  Future<String> changeAvatar(Uint8List bytes) async {
    final userId = _client.auth.currentUser!.id;
    final url = await _uploadAvatar(userId, bytes);
    await _client.from('profiles').update({'avatar_url': url}).eq('id', userId);
    return url;
  }

  /// CV'yi (PDF) cvs deposuna `{uid}/cv.pdf` yoluna yükler ve
  /// profiles.cv_path'i günceller; dosya yolunu döndürür.
  /// Depo özeldir: yalnızca sahibi ve eşleştikleri okuyabilir.
  Future<String> uploadCv(Uint8List bytes) async {
    final userId = _client.auth.currentUser!.id;
    final path = '$userId/cv.pdf';
    await _client.storage
        .from('cvs')
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'application/pdf',
            upsert: true,
          ),
        );
    await _client.from('profiles').update({'cv_path': path}).eq('id', userId);
    return path;
  }

  /// Özel depodaki CV için kısa ömürlü imzalı URL üretir.
  /// RLS gereği yalnızca sahibi ve eşleştikleri üretebilir.
  Future<String> cvSignedUrl(String cvPath) {
    return _client.storage.from('cvs').createSignedUrl(cvPath, 3600);
  }

  /// Giriş yapan kullanıcının arayış etiketlerini getirir (veritabanı
  /// formunda, küçük harf). Deste ve profil görüntülemede "eşleşme
  /// nedeni" vurgusu için kullanılır; hafif tek kolonluk sorgudur.
  Future<Set<String>> getMyLookingFor() async {
    final userId = _client.auth.currentUser!.id;
    final row = await _client
        .from('profiles')
        .select('looking_for')
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return {};
    return Set<String>.from(row['looking_for'] as List? ?? const []);
  }

  /// Bir kullanıcının tam profilini getirir (eşleşilen kişinin profil
  /// görüntüleme ekranı için; profilleri giriş yapan herkes okuyabilir).
  Future<Profile> getProfileOf(String userId) async {
    final row = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .single();
    return Profile.fromJson(row);
  }

  /// Bir kullanıcının cv_path'ini getirir (sohbette "CV'yi görüntüle"
  /// için; CV yoksa null).
  Future<String?> getCvPathOf(String userId) async {
    final row = await _client
        .from('profiles')
        .select('cv_path')
        .eq('id', userId)
        .maybeSingle();
    return row == null ? null : row['cv_path'] as String?;
  }

  /// Etiketin veritabanı hali: Türkçe kurallarına göre küçük harf.
  static String toDbTag(String tag) => turkishLower(tag);

  /// Hata nesnesini kullanıcıya gösterilecek Türkçe mesaja çevirir.
  static String errorMessage(Object error) {
    if (error is StorageException) {
      return 'Fotoğraf yüklenemedi. Lütfen tekrar dene.';
    }
    if (error is PostgrestException) {
      return 'Profil kaydedilemedi. Lütfen tekrar dene.';
    }
    return 'Bağlantı kurulamadı. İnternet bağlantını kontrol et.';
  }
}
