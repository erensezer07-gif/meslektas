import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../main.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/form_feedback.dart';
import '../widgets/splash_gate.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

/// Giriş ekranı: e-posta + şifre (docs/mvp.md §4.1)
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;
  String? _serverError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _serverError = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await AuthService(supabase).signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      // Profil kontrolü SplashGate'te: yoksa onboarding, varsa ana ekran
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SplashGate()),
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
                            Text('Eşleşme', style: textTheme.headlineMedium),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'Yetkinlikler ve arayışlar üzerinden profesyonel eşleşme',
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
                              autofillHints: const [AutofillHints.password],
                              decoration: InputDecoration(
                                labelText: 'Şifre',
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
                              validator: (value) =>
                                  (value == null || value.isEmpty)
                                  ? 'Şifreni gir.'
                                  : null,
                              onFieldSubmitted: (_) => _submit(),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _loading
                                    ? null
                                    : () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const ForgotPasswordScreen(),
                                        ),
                                      ),
                                child: const Text('Şifremi unuttum'),
                              ),
                            ),
                            if (_serverError != null) ...[
                              const SizedBox(height: AppSpacing.sm),
                              ServerErrorBox(message: _serverError!),
                            ],
                            const SizedBox(height: AppSpacing.lg),
                            ElevatedButton(
                              onPressed: _loading ? null : _submit,
                              child: _loading
                                  ? const ButtonProgress()
                                  : const Text('Giriş yap'),
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Hesabın yok mu?',
                                  style: textTheme.bodySmall,
                                ),
                                TextButton(
                                  onPressed: _loading
                                      ? null
                                      : () => Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const RegisterScreen(),
                                          ),
                                        ),
                                  child: const Text('Kayıt ol'),
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
