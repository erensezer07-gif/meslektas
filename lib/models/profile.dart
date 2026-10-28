/// Giriş yapan kullanıcının tam profili (profiles tablosunun tamamı;
/// zorunlu çekirdek + "Profilini güçlendir" opsiyonel alanları).
class Profile {
  const Profile({
    required this.id,
    required this.fullName,
    this.title,
    this.bio,
    this.city,
    required this.skills,
    required this.lookingFor,
    this.avatarUrl,
    this.heightCm,
    this.weightKg,
    this.cvPath,
    this.experienceYears,
    this.education,
    required this.languages,
    this.linkLinkedin,
    this.linkGithub,
    this.linkWebsite,
    this.workPreference,
    required this.certificates,
  });

  final String id;
  final String fullName;
  final String? title;
  final String? bio;
  final String? city;

  /// Veritabanındaki küçük harfli halleri; görüntülerken displayTag kullan.
  final List<String> skills;
  final List<String> lookingFor;
  final String? avatarUrl;
  final int? heightCm;
  final int? weightKg;

  /// cvs deposundaki dosya yolu (örn. "{uid}/cv.pdf"); yalnızca
  /// eşleşilen kişiler imzalı URL ile açabilir.
  final String? cvPath;
  final int? experienceYears;
  final String? education;
  final List<String> languages;
  final String? linkLinkedin;
  final String? linkGithub;
  final String? linkWebsite;

  /// 'yerinde' | 'uzaktan' | 'hibrit' (DB check kısıtıyla aynı)
  final String? workPreference;
  final List<String> certificates;

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      title: json['title'] as String?,
      bio: json['bio'] as String?,
      city: json['city'] as String?,
      skills: List<String>.from(json['skills'] as List? ?? const []),
      lookingFor: List<String>.from(json['looking_for'] as List? ?? const []),
      avatarUrl: json['avatar_url'] as String?,
      heightCm: json['height_cm'] as int?,
      weightKg: json['weight_kg'] as int?,
      cvPath: json['cv_path'] as String?,
      experienceYears: json['experience_years'] as int?,
      education: json['education'] as String?,
      languages: List<String>.from(json['languages'] as List? ?? const []),
      linkLinkedin: json['link_linkedin'] as String?,
      linkGithub: json['link_github'] as String?,
      linkWebsite: json['link_website'] as String?,
      workPreference: json['work_preference'] as String?,
      certificates: List<String>.from(
        json['certificates'] as List? ?? const [],
      ),
    );
  }

  /// Profil doluluk oranı (0-1): zorunlu çekirdek + opsiyonel alanlar.
  /// "Profilin %70 dolu" çubuğu bunu gösterir (docs/mvp.md §4.2).
  double get completeness {
    final checks = <bool>[
      fullName.trim().isNotEmpty,
      title != null && title!.trim().isNotEmpty,
      city != null,
      avatarUrl != null,
      skills.isNotEmpty,
      lookingFor.isNotEmpty,
      bio != null && bio!.trim().isNotEmpty,
      heightCm != null && weightKg != null,
      cvPath != null,
      experienceYears != null,
      education != null && education!.trim().isNotEmpty,
      languages.isNotEmpty,
      linkLinkedin != null || linkGithub != null || linkWebsite != null,
      workPreference != null,
      certificates.isNotEmpty,
    ];
    return checks.where((filled) => filled).length / checks.length;
  }
}
