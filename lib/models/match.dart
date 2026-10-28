/// Karşılıklı beğeniyle oluşan eşleşme; listede karşı tarafın
/// özet profiliyle birlikte gösterilir.
class Match {
  const Match({required this.id, required this.createdAt, required this.other});

  final int id;
  final DateTime createdAt;

  /// Eşleşmenin karşı tarafı (listede gösterilen kişi)
  final MatchProfile other;

  /// matches satırı + iki profil embed'inden model üretir;
  /// hangi taraf giriş yapan kullanıcı değilse "karşı taraf" odur.
  factory Match.fromJson(Map<String, dynamic> json, String currentUserId) {
    final user1 = MatchProfile.fromJson(json['user1'] as Map<String, dynamic>);
    final user2 = MatchProfile.fromJson(json['user2'] as Map<String, dynamic>);
    return Match(
      id: json['id'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      other: user1.id == currentUserId ? user2 : user1,
    );
  }
}

/// Eşleşme listesinde ve sohbet başlığında gereken özet profil
class MatchProfile {
  const MatchProfile({
    required this.id,
    required this.fullName,
    this.title,
    this.avatarUrl,
  });

  final String id;
  final String fullName;
  final String? title;
  final String? avatarUrl;

  factory MatchProfile.fromJson(Map<String, dynamic> json) {
    return MatchProfile(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      title: json['title'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }
}
