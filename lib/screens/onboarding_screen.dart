import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';

import '../main.dart';
import '../services/profile_service.dart';
import '../theme/app_theme.dart';
import '../widgets/city_picker.dart';
import '../widgets/form_feedback.dart';
import '../widgets/tag_selector.dart';
import 'deck_screen.dart';

/// Onboarding: profil oluşturma (docs/mvp.md §4.2 zorunlu çekirdek).
/// 3 adım: kimlik (ad, ünvan, şehir) → fotoğraf → etiketler.
/// Kaydetme en sonda topluca yapılır; yarım profil oluşmaz.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentStep = 0;

  // Adım 1: kimlik
  final _identityFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _titleController = TextEditingController();
  String? _city;
  String? _cityError;

  // Adım 2: fotoğraf
  Uint8List? _avatarBytes;
  String? _photoError;

  // Adım 3: etiketler
  final Set<String> _skills = {};
  final Set<String> _lookingFor = {};
  String? _tagsError;

  bool _saving = false;
  String? _serverError;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    setState(() => _currentStep = step);
    _pageController.animateToPage(
      step,
      duration: AppDurations.normal,
      curve: Curves.easeOutCubic,
    );
  }

  /// "İleri": aktif adımın doğrulamasından geçerse sonraki adıma gider.
  void _next() {
    switch (_currentStep) {
      case 0:
        final formOk = _identityFormKey.currentState!.validate();
        setState(() {
          _cityError = _city == null ? 'Şehrini seç.' : null;
        });
        if (formOk && _cityError == null) _goToStep(1);
      case 1:
        if (_avatarBytes == null) {
          setState(() => _photoError = 'Devam etmek için bir fotoğraf ekle.');
        } else {
          _goToStep(2);
        }
      case 2:
        _save();
    }
  }

  Future<void> _pickPhoto() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked == null) return; // kullanıcı vazgeçti, sessizce dön
      final bytes = await picked.readAsBytes();
      if (mounted) {
        setState(() {
          _avatarBytes = bytes;
          _photoError = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _photoError = 'Fotoğraf seçilemedi. Lütfen tekrar dene.',
        );
      }
    }
  }

  Future<void> _save() async {
    if (_skills.isEmpty || _lookingFor.isEmpty) {
      setState(() {
        _tagsError = _skills.isEmpty
            ? 'En az bir yetkinlik seç.'
            : 'En az bir arayış seç.';
      });
      return;
    }

    setState(() {
      _tagsError = null;
      _serverError = null;
      _saving = true;
    });
    try {
      await ProfileService(supabase).saveProfile(
        fullName: _nameController.text,
        title: _titleController.text,
        city: _city!,
        skills: _skills.toList(),
        lookingFor: _lookingFor.toList(),
        avatarBytes: _avatarBytes!,
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const DeckScreen()),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _serverError = ProfileService.errorMessage(e);
        });
      }
    }
  }

  Future<void> _pickCity() async {
    final selected = await showCityPicker(context);
    if (selected != null) {
      setState(() {
        _city = selected;
        _cityError = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLastStep = _currentStep == 2;

    return Scaffold(
      appBar: AppBar(
        // İlk adımda geri yok (çıkış giriş ekranına düşürmesin);
        // sonraki adımlarda bir önceki adıma döner.
        leading: _currentStep == 0
            ? null
            : IconButton(
                onPressed: _saving ? null : () => _goToStep(_currentStep - 1),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
        automaticallyImplyLeading: false,
        title: const Text('Profilini oluştur'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.md,
                  ),
                  child: _StepProgressBar(current: _currentStep, total: 3),
                ),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    // Adım atlamayı engelle; geçiş yalnızca butonlarla
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildIdentityStep(),
                      _buildPhotoStep(),
                      _buildTagsStep(),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_serverError != null) ...[
                        ServerErrorBox(message: _serverError!),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      ElevatedButton(
                        onPressed: _saving ? null : _next,
                        child: _saving
                            ? const ButtonProgress()
                            : Text(isLastStep ? 'Profili oluştur' : 'İleri'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------- Adım 1: Kimlik ----------

  Widget _buildIdentityStep() {
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      child: Form(
        key: _identityFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Kendini tanıt', style: textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.sm),
            Text('Bu bilgiler profilinde görünür.', style: textTheme.bodySmall),
            const SizedBox(height: AppSpacing.xxl),
            TextFormField(
              controller: _nameController,
              enabled: !_saving,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
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
              decoration: const InputDecoration(
                labelText: 'Ünvan',
                hintText: 'Örn. Tesisat Ustası, Yazılımcı, CEO',
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Ünvanını gir; profilinde adının altında görünür.'
                  : null,
            ),
            const SizedBox(height: AppSpacing.lg),
            // Şehir: bottom sheet'ten seçilir, alan salt görüntüler
            InkWell(
              onTap: _saving ? null : _pickCity,
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
          ],
        ),
      ),
    ).animate().fadeIn(duration: AppDurations.normal);
  }

  // ---------- Adım 2: Fotoğraf ----------

  Widget _buildPhotoStep() {
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Profil fotoğrafı', style: textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Yüzünün net göründüğü bir fotoğraf güven verir.',
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xxl),
          Center(
            child: InkWell(
              onTap: _saving ? null : _pickPhoto,
              customBorder: const CircleBorder(),
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border),
                  image: _avatarBytes == null
                      ? null
                      : DecorationImage(
                          image: MemoryImage(_avatarBytes!),
                          fit: BoxFit.cover,
                        ),
                ),
                child: _avatarBytes == null
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_a_photo_outlined,
                            color: AppColors.textTertiary,
                            size: 32,
                          ),
                          SizedBox(height: AppSpacing.sm),
                          Text(
                            'Fotoğraf ekle',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ],
                      )
                    : null,
              ),
            ),
          ),
          if (_avatarBytes != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Center(
              child: TextButton.icon(
                onPressed: _saving ? null : _pickPhoto,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Değiştir'),
              ),
            ),
          ],
          if (_photoError != null) ...[
            const SizedBox(height: AppSpacing.lg),
            ServerErrorBox(message: _photoError!),
          ],
        ],
      ),
    ).animate().fadeIn(duration: AppDurations.normal);
  }

  // ---------- Adım 3: Etiketler ----------

  Widget _buildTagsStep() {
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Etiketlerini seç', style: textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Eşleşmeler bu etiketlerin örtüşmesine göre sıralanır. '
            'Her iki bölümden en az birer etiket seç.',
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xl),
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
        ],
      ),
    ).animate().fadeIn(duration: AppDurations.normal);
  }
}

/// Üstteki adım ilerleme göstergesi: dolu/boş ince çubuklar.
class _StepProgressBar extends StatelessWidget {
  const _StepProgressBar({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: AnimatedContainer(
              duration: AppDurations.normal,
              height: 4,
              decoration: BoxDecoration(
                color: i <= current ? AppColors.primary : AppColors.border,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
