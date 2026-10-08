import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'database/db_helper.dart';
import 'env/app_config.dart';
import 'pages/main_shell.dart';
import 'pages/pin_login_page.dart';
import 'services/settings_controller.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
    );
  } catch (e) {
    // Supabase belum dikonfigurasi → aplikasi tetap jalan (PIN fallback lokal).
    debugPrintFallback('Supabase init skipped: $e');
  }

  final settings = SettingsController();
  await Future.wait([
    settings.load(),
    DbHelper.instance.initCloud(),
  ]);
  // Seeding otomatis dari Excel jika database cloud masih kosong.
  await DbHelper.instance.seedIfEmpty();

  runApp(SpekKomputerApp(settings: settings));
}

class SpekKomputerApp extends StatefulWidget {
  final SettingsController settings;
  const SpekKomputerApp({super.key, required this.settings});

  @override
  State<SpekKomputerApp> createState() => _SpekKomputerAppState();
}

/// Gerbang PIN: tampilkan layar PIN sampai berhasil, baru ke MainShell.
class _PinGate extends StatefulWidget {
  final SettingsController settings;
  const _PinGate({required this.settings});

  @override
  State<_PinGate> createState() => _PinGateState();
}

class _PinGateState extends State<_PinGate> {
  bool _unlocked = false;

  @override
  Widget build(BuildContext context) {
    if (!_unlocked) {
      return PinLoginPage(onSuccess: () => setState(() => _unlocked = true));
    }
    return MainShell(key: UniqueKey(), settings: widget.settings);
  }
}

class _SpekKomputerAppState extends State<SpekKomputerApp> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.settings,
      builder: (context, _) {
        final platformDark =
            MediaQuery.platformBrightnessOf(context) == Brightness.dark;
        final themeMode = widget.settings.mode;
        final effectiveDark = switch (themeMode) {
          ThemeMode.light => false,
          ThemeMode.dark => true,
          ThemeMode.system => platformDark,
        };

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness:
                effectiveDark ? Brightness.light : Brightness.dark,
            statusBarBrightness:
                effectiveDark ? Brightness.dark : Brightness.light,
          ),
          child: MaterialApp(
            title: 'Spek Inventaris DPR',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: themeMode,
            home: _PinGate(settings: widget.settings),
          ),
        );
      },
    );
  }
}