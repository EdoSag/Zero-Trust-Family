import 'dart:async';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

import '../data/locations.dart';
import '../l10n/l10n.dart';
import 'schedule.dart';
import 'share_engine.dart';

/// The link between the Android sharing service (`ShareService.kt`) and
/// [ShareEngine], over channel `zt_family/share`.
///
/// The service asks for positions on the schedule and hands each one here;
/// the answer says how often to ask next and what the notification says.
class ShareChannel implements ShareServiceControl {
  ShareChannel(this.engine, {Future<void>? ready}) : _ready = ready;

  final ShareEngine engine;
  final Future<void>? _ready;
  static const _channel = MethodChannel('zt_family/share');

  /// Takes the service's calls. Called in `main()` before anything slow, so
  /// a service that starts the app in the background finds a listener.
  void attach() {
    _channel.setMethodCallHandler((call) async {
      await _ready;
      final args = (call.arguments as Map?) ?? const {};
      final ShareResult result;
      switch (call.method) {
        case 'fix':
          final fix = Fix.fromMap(args);
          final status = DeviceStatus.fromMap(args);
          result = fix == null
              ? await engine.current()
              : await engine.onFix(fix, status);
        case 'motion':
          result = await engine.onMotion();
        case 'started':
          result = await engine.current();
        default:
          throw MissingPluginException(call.method);
      }
      return _answer(result);
    });
  }

  Future<Map<String, Object?>> _answer(ShareResult result) async {
    final l = lookupAppL10n(await _locale());
    final (title, text) = switch (result.health) {
      ShareHealth.sharing ||
      ShareHealth.offline => (l.notifySharingTitle, l.notifySharingBody),
      ShareHealth.paused => (l.notifyPausedTitle, l.notifyPausedBody),
      ShareHealth.needsUnlock => (l.notifyUnlockTitle, l.notifyUnlockBody),
      ShareHealth.stopped => (l.notifySharingTitle, l.notifySharingBody),
    };
    return {
      'stop': result.stop,
      'intervalMs': result.decision.interval.inMilliseconds,
      'title': title,
      'text': text,
      'channelName': l.notifyChannelName,
    };
  }

  /// The language picked in Settings, or the phone's.
  static Future<Locale> _locale() async {
    String? stored;
    try {
      stored = await SecurePreferencesStore().read('language');
    } on Object {
      stored = null;
    }
    final phone = PlatformDispatcher.instance.locale;
    final code = stored == null || stored == 'phone'
        ? phone.languageCode
        : stored;
    for (final locale in ZtLanguages.supported) {
      if (locale.languageCode == code) return locale;
    }
    return ZtLanguages.english;
  }

  @override
  Future<void> start() async {
    try {
      await _channel.invokeMethod<void>('start');
    } on MissingPluginException {
      // Tests and platforms without the service.
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _channel.invokeMethod<void>('stop');
    } on MissingPluginException {
      // As above.
    }
  }

  @override
  Future<void> poke() async {
    try {
      await _channel.invokeMethod<void>('poke');
    } on MissingPluginException {
      // As above.
    }
  }

  @override
  Future<SharePermissions> permissions() async => SharePermissions(
    location: await Permission.locationWhenInUse.isGranted,
    background: await Permission.locationAlways.isGranted,
    notifications: await Permission.notification.isGranted,
  );

  /// Asks in the order Android requires: location while in use, then "Allow
  /// all the time" (Android shows its settings screen for that one), then
  /// notifications.
  @override
  Future<SharePermissions> requestPermissions() async {
    if (!await Permission.locationWhenInUse.request().isGranted) {
      return permissions();
    }
    if (!await Permission.locationAlways.isGranted) {
      await Permission.locationAlways.request();
    }
    if (!await Permission.notification.isGranted) {
      await Permission.notification.request();
    }
    return permissions();
  }
}
