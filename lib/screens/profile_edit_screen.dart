import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/tags.dart';
import '../main.dart';
import '../models/profile.dart';
import '../services/profile_service.dart';
import '../theme/app_theme.dart';
import '../widgets/city_picker.dart';
import '../widgets/form_feedback.dart';
import '../widgets/tag_selector.dart';

/// Profil düzenleme (docs/mvp.md §4.2): zorunlu çekirdek +
/// "Profilini güçlendir" opsiyonel alanları + CV yükleme.
/// Doluluk çubuğu kullanıcıyı opsiyonel alanlara teşvik eder.
class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  Profile? _profile;
  String? _loadError;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _titleController = TextEditingController();
  final _bioController = TextEditingController();
  final _experienceController = TextEditingController();
  final _educationController = TextEditingController();
  final _languagesController = TextEditingController();
  final _linkedinController = TextEditingController();
  final _githubController = TextEditingController();
  final _websiteController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _certificatesController = TextEditingController();

  String? _city;
  String? _cityError;
  final Set<String> _skills = {};
  final Set<String> _lookingFor = {};
  String? _tagsError;
  String? _workPreference;
  String? _avatarUrl;
  String? _cvPath;

  bool _saving = false;
  bool _avatarBusy = false;
  bool _cvBusy = false;
  String? _serverError;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    for (final controller in [
      _nameController,
      _titleController,
      _bioController,
      _experienceController,
      _educationController,
      _languagesController,
      _linkedinController,
      _githubController,
      _websiteController,
      _heightController,
      _weightController,
      _certificatesController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _profile = null;
      _loadError = null;
    });
    try {
      final profile = await ProfileService(supabase).getMyProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _fillForm(profile);
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loadError = ProfileService.errorMessage(e));
      }
    }
  }

  void _fillForm(Profile profile) {
    _nameController.text = profile.fullName;
    _titleController.text = profile.title ?? '';
    _bioController.text = profile.bio ?? '';
    _experienceController.text = profile.experienceYears?.toString() ?? '';
    _educationController.text = profile.education ?? '';
    _languagesController.text = profile.languages.join(', ');
    _linkedinController.text = profile.linkLinkedin ?? '';
    _githubController.text = profile.linkGithub ?? '';
    _websiteController.text = profile.linkWebsite ?? '';
    _heightController.text = profile.heightCm?.toString() ?? '';
    _weightController.text = profile.weightKg?.toString() ?? '';
    _certificatesController.text = profile.certificates.join(', ');
    _city = profile.city;
    _skills
      ..clear()
      ..addAll(profile.skills.map(displayTag));
    _lookingFor
      ..clear()
      ..addAll(profile.lookingFor.map(displayTag));
    _workPreference = profile.workPreference;
    _avatarUrl = profile.avatarUrl;
    _cvPath = profile.cvPath;
  }

  // ---------- Fotoğraf ve CV ----------

  Future<void> _changePhoto() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() => _avatarBusy = true);
      final url = await ProfileService(supabase).changeAvatar(bytes);
      if (mounted) {
        setState(() {
          _avatarUrl = url;
          _avatarBusy = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _avatarBusy = false);
        _showSnack(ProfileService.errorMessage(e));
      }
    }
  }

  Future<void> _uploadCv() async {
    try {
      const pdfGroup = XTypeGroup(
        label: 'PDF',
        extensions: ['pdf'],
        mimeTypes: ['application/pdf'],
      );
      final file = await openFile(acceptedTypeGroups: const [pdfGroup]);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      // Ücretsiz katman dostu üst sınır
      if (bytes.length > 10 * 1024 * 1024) {
        _showSnack('CV dosyası 10 MB\'tan büyük olamaz.');
        return;
      }
      if (!mounted) return;
      setState(() => _cvBusy = true);
      final path = await ProfileService(supabase).uploadCv(bytes);
      if (mounted) {
        setState(() {
          _cvPath = path;
          _cvBusy = false;
        });
        _showSnack('CV yüklendi. Yalnızca eşleştiğin kişiler görebilir.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cvBusy = false);
        _showSnack(ProfileService.errorMessage(e));
      }
    }
  }

  Future<void> _viewCv() async {
    if (_cvPath == null) return;
    try {
      final url = await ProfileService(supabase).cvSignedUrl(_cvPath!);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      _showSnack('CV açılamadı. Lütfen tekrar dene.');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // ---------- Kaydetme ----------

  /// Boş metni null'a çevirir (opsiyonel alanlar temizlenebilsin)
  String? _emptyToNull(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : text;
  }

  /// Virgülle ayrılmış girdiyi listeye çevirir
  List<String> _splitList(TextEditingController controller) {
    return controller.text
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  /// Bağlantıyı normalleştirir: şema yoksa https:// eklenir
  String? _normalizeLink(TextEditingController controller) {
    final text = _emptyToNull(controller);
    if (text == null) return null;
    return text.startsWith('http://') || text.startsWith('https://')
        ? text
        : 'https://$text';
  }

  Future<void> _save() async {
    setState(() {
      _serverError = null;
      _cityError = _city == null ? 'Şehrini seç.' : null;
      _tagsError = _skills.isEmpty
          ? 'En az bir yetkinlik seçili olmalı.'
          : _lookingFor.isEmpty
          ? 'En az bir arayış seçili olmalı.'
          : null;
    });
    final formOk = _formKey.currentState!.validate();
    if (!formOk || _cityError != null || _tagsError != null) return;

    setState(() => _saving = true);
    try {
      await ProfileService(supabase).updateProfile(
        fullName: _nameController.text,
        title: _titleController.text,
        city: _city!,
        skills: _skills.toList(),
        lookingFor: _lookingFor.toList(),
        bio: _emptyToNull(_bioController),
        heightCm: int.tryParse(_heightController.text.trim()),
        weightKg: int.tryParse(_weightController.text.trim()),
        experienceYears: int.tryParse(_experienceController.text.trim()),
        education: _emptyToNull(_educationController),
        languages: _splitList(_languagesController),
        linkLinkedin: _normalizeLink(_linkedinController),
        linkGithub: _normalizeLink(_githubController),
        linkWebsite: _normalizeLink(_websiteController),
        workPreference: _workPreference,
        certificates: _splitList(_certificatesController),
      );
      if (!mounted) return;
      setState(() => _saving = false);
      _showSnack('Profilin güncellendi.');
      // Doluluk çubuğu güncellensin diye profili tazele
      final refreshed = await ProfileService(supabase).getMyProfile();
      if (mounted) setState(() => _profile = refreshed);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _serverError = ProfileService.errorMessage(e);
        });
      }
    }
  }

  // ---------- Arayüz ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profilim')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: _loadError != null
                ? _buildError()
                : _profile == null
                ? _buildLoading()
                : _buildForm(),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    final textTheme = Theme.of(context).textTheme;
    final percent = (_profile!.completeness * 100).round();

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          // Doluluk çubuğu
          Text('Profilin %$percent dolu', style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: LinearProgressIndicator(
              value: _profile!.completeness,
              minHeight: 6,
              backgroundColor: AppColors.surfaceSubtle,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),

          // Fotoğraf
          Center(
            child: Stack(
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSubtle,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border),
                    image: _avatarUrl == null
                        ? null
                        : DecorationImage(
                            image: NetworkImage(_avatarUrl!),
                            fit: BoxFit.cover,
                          ),
                  ),
                  child: _avatarBusy
                      ? const Center(child: ButtonProgress())
                      : _avatarUrl == null
                      ? const Icon(
                          Icons.person_outline_rounded,
                          size: 48,
                          color: AppColors.textTertiary,
                        )
                      : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: IconButton(
                    onPressed: _avatarBusy || _saving ? null : _changePhoto,
                    tooltip: 'Fotoğrafı değiştir',
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.edit_rounded, size: 18),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),

          // Zorunlu çekirdek
          TextFormField(
            controller: _nameController,
            enabled: !_saving,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Ad soyad'),
            validator: (value) {
              final v = value?.trim() ?? '';
              if (v.isEmpty) return 'Adını ve soyadını gir.';
              if (v.length < 3) return 'Ad soyad en az 3 karakter olmalı.';
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          TextFormField(
            controller: _titleController,
            enabled: !_saving,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Ünvan'),
            validator: (value) => (value == null || value.trim().isEmpty)
                ? 'Ünvanını gir.'
                : null,
          ),
          const SizedBox(height: AppSpacing.lg),
          InkWell(
            onTap: _saving
                ? null
                : () async {
                    final selected = await showCityPicker(context);
                    if (selected != null) {
                      setState(() {
                        _city = selected;
                        _cityError = null;
                      });
                    }
                  },
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Şehir',
                errorText: _cityError,
                suffixIcon: const Icon(Icons.expand_more_rounded),
              ),
              child: Text(
                _city ?? 'Seç',
                style: TextStyle(
                  color: _city == null
                      ? AppColors.textTertiary
                      : AppColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),

          // Etiketler
          TagSelector(
            title: 'Neler yapıyorsun?',
            subtitle: 'Yetkinliklerin — sunduğun işler',
            selected: _skills,
            enabled: !_saving,
            onChanged: () => setState(() => _tagsError = null),
          ),
          const SizedBox(height: AppSpacing.xl),
          TagSelector(
            title: 'Ne arıyorsun?',
            subtitle: 'Arayışların — aradığın yetkinlikler',
            selected: _lookingFor,
            enabled: !_saving,
            onChanged: () => setState(() => _tagsError = null),
          ),
          if (_tagsError != null) ...[
            const SizedBox(height: AppSpacing.lg),
            ServerErrorBox(message: _tagsError!),
          ],
          const SizedBox(height: AppSpacing.xxl),

          // Profilini güçlendir
          Text('Profilini güçlendir', style: textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Bu alanlar isteğe bağlıdır; doldukça profilin öne çıkar.',
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.lg),

          // CV
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.description_outlined,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('CV (PDF)', style: textTheme.titleMedium),
                      Text(
                        _cvPath == null
                            ? 'Yalnızca eşleştiğin kişiler görebilir.'
                            : 'CV yüklü.',
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (_cvBusy)
                  const ButtonProgress()
                else ...[
                  if (_cvPath != null)
                    TextButton(
                      onPressed: _saving ? null : _viewCv,
                      child: const Text('Görüntüle'),
                    ),
                  TextButton(
                    onPressed: _saving ? null : _uploadCv,
                    child: Text(_cvPath == null ? 'Yükle' : 'Değiştir'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          TextFormField(
            controller: _bioController,
            enabled: !_saving,
            minLines: 3,
            maxLines: 6,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: 'Kısa tanıtım',
              hintText: 'Kendini birkaç cümleyle anlat',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _experienceController,
                  enabled: !_saving,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Deneyim (yıl)'),
                  validator: (value) => _rangeValidator(value, 0, 60),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: TextFormField(
                  controller: _heightController,
                  enabled: !_saving,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Boy (cm)'),
                  validator: (value) => _rangeValidator(value, 100, 250),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: TextFormField(
                  controller: _weightController,
                  enabled: !_saving,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Kilo (kg)'),
                  validator: (value) => _rangeValidator(value, 30, 300),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          TextFormField(
            controller: _educationController,
            enabled: !_saving,
            decoration: const InputDecoration(
              labelText: 'Eğitim',
              hintText: 'Okul · Bölüm',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextFormField(
            controller: _languagesController,
            enabled: !_saving,
            decoration: const InputDecoration(
              labelText: 'Diller',
              hintText: 'Virgülle ayır: Türkçe, İngilizce',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextFormField(
            controller: _certificatesController,
            enabled: !_saving,
            decoration: const InputDecoration(
              labelText: 'Sertifikalar',
              hintText: 'Virgülle ayır',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Çalışma tercihi
          Text('Çalışma tercihi', style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final (value, label) in const [
                ('yerinde', 'Yerinde'),
                ('uzaktan', 'Uzaktan'),
                ('hibrit', 'Hibrit'),
              ])
                ChoiceChip(
                  label: Text(label),
                  selected: _workPreference == value,
                  showCheckmark: false,
                  onSelected: _saving
                      ? null
                      : (selected) => setState(
                          () => _workPreference = selected ? value : null,
                        ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          TextFormField(
            controller: _linkedinController,
            enabled: !_saving,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(labelText: 'LinkedIn'),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextFormField(
            controller: _githubController,
            enabled: !_saving,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(labelText: 'GitHub / Portfolyo'),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextFormField(
            controller: _websiteController,
            enabled: !_saving,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(labelText: 'Web sitesi'),
          ),

          if (_serverError != null) ...[
            const SizedBox(height: AppSpacing.lg),
            ServerErrorBox(message: _serverError!),
          ],
          const SizedBox(height: AppSpacing.xl),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving ? const ButtonProgress() : const Text('Kaydet'),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    ).animate().fadeIn(duration: AppDurations.normal);
  }

  static String? _rangeValidator(String? value, int min, int max) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null; // opsiyonel
    final number = int.tryParse(text);
    if (number == null || number < min || number > max) {
      return '$min-$max arası';
    }
    return null;
  }

  /// Yükleme: form biçiminde shimmer iskelet (spinner yok)
  Widget _buildLoading() {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceSubtle,
      highlightColor: AppColors.background,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: const BoxDecoration(
                color: AppColors.surfaceSubtle,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          for (var i = 0; i < 5; i++) ...[
            Container(
              height: 52,
              margin: const EdgeInsets.only(bottom: AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surfaceSubtle,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildError() {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: const BoxDecoration(
              color: AppColors.errorSurface,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.wifi_off_rounded,
              color: AppColors.error,
              size: 32,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Profil yüklenemedi', style: textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _loadError!,
            style: textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          OutlinedButton(
            onPressed: _loadProfile,
            child: const Text('Tekrar dene'),
          ),
        ],
      ),
    );
  }
}
