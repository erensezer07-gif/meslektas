import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../main.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/form_feedback.dart';

/// Şifre sıfırlama ekranı (docs/mvp.md §4.1)
/// MVP kapsamı: yalnızca sıfırlama e-postası göndermek.
/// TODO(v-sonrası): Bağlantıya tıklandıktan sonraki "yeni şifre belirleme"
/// ekranı kapsam dışı; deep link kurulumu ile birlikte eklenecek.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _loading = false;
  bool _sent = false;
  String? _serverError;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _serverError = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await AuthService(supabase).resetPassword(_emailController.text.trim());
      if (mounted) setState(() => _sent = true);
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
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: _sent ? _buildSent(context) : _buildForm(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Şifreni mi unuttun?', style: textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'E-posta adresine bir sıfırlama bağlantısı gönderelim.',
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
                    : const Text('Sıfırlama bağlantısı gönder'),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: AppDurations.normal)
        .slideY(begin: 0.05, end: 0, duration: AppDurations.normal);
  }

  Widget _buildSent(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: const BoxDecoration(
                  color: AppColors.successSurface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mark_email_read_outlined,
                  color: AppColors.success,
                  size: 32,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'E-postanı kontrol et',
              style: textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${_emailController.text.trim()} adresine bir sıfırlama '
              'bağlantısı gönderdik. Gelen kutunu (ve spam klasörünü) kontrol et.',
              style: textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Girişe dön'),
            ),
          ],
        )
        .animate()
        .fadeIn(duration: AppDurations.normal)
        .slideY(begin: 0.05, end: 0, duration: AppDurations.normal);
  }
}
