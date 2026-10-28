/// get_deck() fonksiyonunun döndürdüğü aday profil
/// (docs/schema.sql §6 ile aynı alanlar).
class DeckProfile {
  const DeckProfile({
    required this.id,
    required this.fullName,
    this.title,
    this.bio,
    this.city,
    required this.skills,
    this.avatarUrl,
    required this.matchScore,
  });

  final String id;
  final String fullName;
  final String? title;
  final String? bio;
  final String? city;

  /// Veritabanındaki küçük harfli halleri; görüntülerken displayTag kullan.
  final List<String> skills;
  final String? avatarUrl;
  final int matchScore;

  factory DeckProfile.fromJson(Map<String, dynamic> json) {
    return DeckProfile(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      title: json['title'] as String?,
      bio: json['bio'] as String?,
      city: json['city'] as String?,
      skills: List<String>.from(json['skills'] as List? ?? const []),
      avatarUrl: json['avatar_url'] as String?,
      matchScore: json['match_score'] as int? ?? 0,
    );
  }
}
