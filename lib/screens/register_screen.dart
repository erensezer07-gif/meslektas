import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../main.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/form_feedback.dart';
import 'onboarding_screen.dart';

/// Kayıt ekranı: e-posta + şifre + şifre tekrar (docs/mvp.md §4.1)
/// E-posta doğrulaması panelden kapalı; başarılı kayıt sonrası
/// kullanıcı doğrudan giriş yapmış olur.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordRepeatController = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;
  String? _serverError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordRepeatController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _serverError = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await AuthService(supabase).signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      // Yeni kullanıcının profili olamaz; doğrudan onboarding'e
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _serverError = AuthService.errorMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child:
              SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('Kayıt ol', style: textTheme.headlineMedium),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'Bir e-posta ve şifre yeter; profilini sonra dolduracaksın.',
                              style: textTheme.bodySmall,
                            ),
                            const SizedBox(height: AppSpacing.xxl),
                            TextFormField(
                              controller: _emailController,
                              enabled: !_loading,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              decoration: const InputDecoration(
                                labelText: 'E-posta',
                                hintText: 'ornek@eposta.com',
                              ),
                              validator: validateEmail,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            TextFormField(
                              controller: _passwordController,
                              enabled: !_loading,
                              obscureText: _obscurePassword,
                              autofillHints: const [AutofillHints.newPassword],
                              decoration: InputDecoration(
                                labelText: 'Şifre',
                                helperText: 'En az 6 karakter',
                                suffixIcon: IconButton(
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Bir şifre belirle.';
                                }
                                if (value.length < 6) {
                                  return 'Şifre en az 6 karakter olmalı.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            TextFormField(
                              controller: _passwordRepeatController,
                              enabled: !_loading,
                              obscureText: _obscurePassword,
                              decoration: const InputDecoration(
                                labelText: 'Şifre (tekrar)',
                              ),
                              validator: (value) =>
                                  value != _passwordController.text
                                  ? 'Şifreler eşleşmiyor.'
                                  : null,
                              onFieldSubmitted: (_) => _submit(),
                            ),
                            if (_serverError != null) ...[
                              const SizedBox(height: AppSpacing.lg),
                              ServerErrorBox(message: _serverError!),
                            ],
                            const SizedBox(height: AppSpacing.xl),
                            ElevatedButton(
                              onPressed: _loading ? null : _submit,
                              child: _loading
                                  ? const ButtonProgress()
                                  : const Text('Kayıt ol'),
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Zaten hesabın var mı?',
                                  style: textTheme.bodySmall,
                                ),
                                TextButton(
                                  onPressed: _loading
                                      ? null
                                      : () => Navigator.of(context).pop(),
                                  child: const Text('Giriş yap'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .animate()
                  .fadeIn(duration: AppDurations.normal)
                  .slideY(begin: 0.05, end: 0, duration: AppDurations.normal),
        ),
      ),
    );
  }
}
