import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

import 'app/app_gate.dart';
import 'app/email_links.dart';
import 'app/family_config.dart';
import 'data/alerts.dart';
import 'data/locations.dart';
import 'l10n/l10n.dart';
import 'location/alerts.dart';
import 'location/drive_store.dart';
import 'location/location_backend.dart';
import 'location/share_channel.dart';
import 'location/share_engine.dart';
import 'location/share_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Location sharing runs in this same isolate, also when the Android
  // service starts the app in the background with no screen: the channel
  // listens first and waits for Supabase below.
  final ready = Completer<void>();
  final store = SecureShareStore();
  final backend = SupabaseLocationBackend();
  final engine = ShareEngine(
    store: store,
    backend: backend,
    drives: SecureDriveStore(),
  );
  final alertStore = SecureAlertStore();
  final alerts = AlertEngine(store: alertStore, backend: backend);
  final share = ShareChannel(engine, alerts: alerts, ready: ready.future)
    ..attach();
  await dotenv.load(fileName: '.env');
  // The language picked in Settings, before the first frame.
  await ZtLanguageController.preload();
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    publishableKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  ready.complete();
  unawaited(EmailLinks.listen());
  runApp(
    ProviderScope(
      overrides: [
        ztAppConfigProvider.overrideWithValue(familyAppConfig),
        ztSpacePolicyProvider.overrideWithValue(familySpacePolicy),
        shareStoreProvider.overrideWithValue(store),
        locationBackendProvider.overrideWithValue(backend),
        shareEngineProvider.overrideWithValue(engine),
        shareServiceProvider.overrideWithValue(share),
        alertStoreProvider.overrideWithValue(alertStore),
      ],
      child: const ZeroTrustFamilyApp(),
    ),
  );
}

class ZeroTrustFamilyApp extends ConsumerWidget {
  const ZeroTrustFamilyApp({super.key, this.home = const AppGate()});

  final Widget home;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ZtThemeBuilder(
      builder: (context, theme, darkTheme, mode) => MaterialApp(
        // On-device task switcher label; the store name is Zero-Trust Family.
        title: 'ZT Family',
        theme: theme,
        darkTheme: darkTheme,
        themeMode: mode,
        // English (default) or Hebrew, from Settings → Appearance → Language.
        locale: ref.watch(ztLanguageProvider),
        supportedLocales: ZtLanguages.supported,
        localizationsDelegates: const [
          AppL10n.delegate,
          ...ZtLanguages.delegates,
        ],
        home: home,
        // Any touch on any screen counts as activity for auto-lock.
        builder: (context, child) => Listener(
          onPointerDown: (_) =>
              ref.read(vaultControllerProvider.notifier).touch(),
          child: child,
        ),
      ),
    );
  }
}
