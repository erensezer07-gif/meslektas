import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'constants/supabase_config.dart';
import 'screens/login_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/splash_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Supabase bağlantısını başlat
  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
  );

  runApp(const EslesmeApp());
}

/// Uygulama genelinde kullanılacak Supabase istemcisi
final supabase = Supabase.instance.client;

class EslesmeApp extends StatelessWidget {
  const EslesmeApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Açılışta oturum kontrolü: oturum varsa profil kontrolüne (SplashGate),
    // yoksa giriş ekranına
    final hasSession = supabase.auth.currentSession != null;

    return MaterialApp(
      title: 'Eşleşme',
      theme: AppTheme.light,
      // Türkçe yerelleştirme: tarih biçimleri ve sistem metinleri
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: hasSession ? const SplashGate() : const LoginScreen(),
    );
  }
}
