import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

import '../data/locations.dart';
import '../l10n/event_text.dart';
import '../l10n/l10n.dart';
import 'alerts.dart';
import 'drive.dart';
import 'family_event.dart';
import 'reminders.dart';
import 'schedule.dart';
import 'share_engine.dart';
import 'share_store.dart';

/// The link between the Android sharing service (`ShareService.kt`) and
/// [ShareEngine], over channel `zt_family/share`.
///
/// The service asks for positions on the schedule and hands each one here;
/// the answer says how often to ask next and what the notification says.
class ShareChannel implements ShareServiceControl {
  ShareChannel(this.engine, {required this.alerts, Future<void>? ready})
    : _ready = ready {
    engine.onReminder = (spaceId, r) => unawaited(_showReminder(r));
  }

  final ShareEngine engine;

  /// Alerts while locked. The service also runs for these alone, without
  /// sharing, and then takes no positions.
  final AlertEngine alerts;
  final Future<void>? _ready;
  static const _channel = MethodChannel('zt_family/share');

  StreamSubscription<void>? _inserts;
  List<String> _watching = const [];

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
        // "I'm OK" on a notification, while locked.
        case 'checkin':
          final space = args['spaceId'];
          if (space is String) await engine.checkIn(space);
          result = await engine.current();
        case 'timerOk':
          await engine.endTimer();
          result = await engine.current();
        // One second each of satellites and accelerometer while driving.
        case 'drive':
          result = await engine.onDrive([
            for (final raw in (args['samples'] as List? ?? const []))
              ?DriveSample.fromMap(raw),
          ]);
        // The crash countdown's buttons, and "I'm safe" after its SOS.
        case 'crashOk':
          await engine.cancelCrash();
          result = await engine.current();
        case 'crashSos':
          await engine.crashSosNow();
          result = await engine.current();
        case 'sosEnd':
          await engine.endSos();
          result = await engine.current();
        default:
          throw MissingPluginException(call.method);
      }
      final alertsOn = await _alertsOn();
      // Every time the service wakes up, look for new alerts too.
      unawaited(_checkAlerts());
      unawaited(_watch());
      return _answer(result, alertsOn: alertsOn);
    });
  }

  Future<bool> _alertsOn() async {
    final state = await alerts.store.load();
    return state != null && state.on;
  }

  Future<Map<String, Object?>> _answer(
    ShareResult result, {
    required bool alertsOn,
  }) async {
    final l = lookupAppL10n(await _locale());
    // Not sharing, but alerts are on: the service stays, without positions.
    final alertsOnly = result.stop && alertsOn;
    final (title, text) = alertsOnly
        ? (l.notifyAlertsTitle, l.notifyAlertsBody)
        : switch (result.health) {
            ShareHealth.sharing ||
            ShareHealth.offline => (l.notifySharingTitle, l.notifySharingBody),
            ShareHealth.paused => (l.notifyPausedTitle, l.notifyPausedBody),
            ShareHealth.needsUnlock => (
              l.notifyUnlockTitle,
              l.notifyUnlockBody,
            ),
            ShareHealth.stopped => (l.notifySharingTitle, l.notifySharingBody),
          };
    final state = await engine.store.load();
    final timer = state?.timer;
    final now = DateTime.now();
    DateTime? wakeAt;
    if (timer != null) {
      final remind = timer.until.subtract(timerReminder);
      if (now.isBefore(remind)) {
        wakeAt = remind;
      } else {
        wakeAt = timer.until;
        await _remindTimer(timer.until, l);
      }
    }
    final crash = state?.crash;
    if (crash != null) {
      // The countdown's end comes first: an SOS can't wait for a timer.
      // Past it (offline, or some circles not reached yet), try again in a
      // minute.
      final at = crash.deadline.isAfter(now)
          ? crash.deadline
          : now.add(const Duration(minutes: 1));
      if (wakeAt == null || at.isBefore(wakeAt)) wakeAt = at;
    }
    if (crash != null && crash.counting) {
      await _crashCountdown(crash, l);
    } else {
      await _crashOver(state, l);
    }
    return {
      // Wake up for the safety timer or a crash countdown even if the
      // phone is still.
      if (wakeAt != null) 'wakeAt': wakeAt.millisecondsSinceEpoch,
      // Satellites every second and the accelerometer, while driving.
      'drive': engine.wantsDriveSensors(state, now),
      'stop': result.stop && !alertsOn,
      'locate': !result.stop,
      'intervalMs': alertsOnly
          ? AdaptiveSchedule.stillEvery.inMilliseconds
          : result.decision.interval.inMilliseconds,
      'title': title,
      'text': text,
      'channelName': l.notifyChannelName,
    };
  }

  /// The crash countdown's notification (and, after it, the SOS's).
  static const crashNotification = 0x3fff0001;

  DateTime? _crashShown;

  /// "Were you in a crash? Your circle gets an SOS at 14:32", ringing,
  /// with "I'm OK" and "Send SOS now".
  Future<void> _crashCountdown(CrashRun crash, AppL10n l) async {
    if (_crashShown == crash.at) return;
    _crashShown = crash.at;
    final time = DateFormat.Hms(l.localeName).format(crash.deadline.toLocal());
    try {
      await _channel.invokeMethod<void>('notify', {
        'id': crashNotification,
        'title': l.crashCountdownTitle,
        'text': l.crashCountdownBody(time),
        'quiet': false,
        'urgent': true,
        'ongoing': true,
        'actionLabel': l.imOk,
        'actionKind': 'crashOk',
        'action2Label': l.crashSendNow,
        'action2Kind': 'crashSos',
        'channelName': l.alertsChannelName,
        'quietChannelName': l.alertsQuietChannelName,
        'urgentChannelName': l.sosChannelName,
      });
    } on MissingPluginException {
      // Tests.
    }
  }

  /// After a countdown: says the SOS went out (with "I'm safe"), or takes
  /// the countdown away when the driver was OK.
  Future<void> _crashOver(ShareState? state, AppL10n l) async {
    if (_crashShown == null) return;
    _crashShown = null;
    try {
      if (state?.sos != null) {
        await _channel.invokeMethod<void>('notify', {
          'id': crashNotification,
          'title': l.crashSosSentTitle,
          'text': l.crashSosSentBody,
          'quiet': false,
          'urgent': false,
          'actionLabel': l.imSafe,
          'actionKind': 'sosEnd',
          'channelName': l.alertsChannelName,
          'quietChannelName': l.alertsQuietChannelName,
          'urgentChannelName': l.sosChannelName,
        });
      } else {
        await _channel.invokeMethod<void>('cancel', {'id': crashNotification});
      }
    } on MissingPluginException {
      // Tests.
    }
  }

  /// How long before a safety timer runs out its owner is reminded.
  static const timerReminder = Duration(minutes: 10);

  DateTime? _reminded;

  /// "Your safety timer ends at 23:30", with an "I'm OK" button.
  Future<void> _remindTimer(DateTime until, AppL10n l) async {
    if (_reminded == until) return;
    _reminded = until;
    final time = DateFormat.Hm(l.localeName).format(until.toLocal());
    try {
      await _channel.invokeMethod<void>('notify', {
        'id': until.millisecondsSinceEpoch ~/ 1000 & 0x3fffffff,
        'title': l.timerReminderTitle(time),
        'text': l.timerReminderBody,
        'quiet': false,
        'urgent': false,
        'actionLabel': l.imOk,
        'actionKind': 'timerOk',
        'channelName': l.alertsChannelName,
        'quietChannelName': l.alertsQuietChannelName,
        'urgentChannelName': l.sosChannelName,
      });
    } on MissingPluginException {
      // Tests.
    }
  }

  /// Follows new events of the alert circles as they arrive (realtime),
  /// while the app's process runs.
  Future<void> _watch() async {
    final state = await alerts.store.load();
    final ids = state == null
        ? <String>[]
        : (state.circles.keys.toList()..sort());
    if (listEquals(ids, _watching)) return;
    _watching = ids;
    await _inserts?.cancel();
    _inserts = null;
    if (ids.isEmpty) return;
    _inserts = alerts.backend.eventInserts(ids).listen((_) => _checkAlerts());
  }

  Future<void> _checkAlerts() async {
    try {
      final hits = await alerts.check();
      if (hits.isEmpty) return;
      final l = lookupAppL10n(await _locale());
      for (final hit in hits) {
        await _reminderHit(hit);
        if (!hit.silent) await _notify(hit, l);
      }
    } on Object {
      // Offline or signed out: the next wake-up tries again.
    }
  }

  /// A reminder set for this phone's member (or taken back), seen while
  /// locked: the service starts (or stops) watching for it.
  Future<void> _reminderHit(AlertHit hit) async {
    switch (hit.event.kind) {
      case FamilyEventKind.remind:
        final r = PlaceReminder.fromEvent(
          hit.userId,
          hit.event,
          fromName: hit.name,
          placeName: hit.placeName,
        );
        if (r != null) await engine.updateReminders(hit.spaceId, add: [r]);
      case FamilyEventKind.remindCancel when hit.event.ref != null:
        await engine.updateReminders(hit.spaceId, drop: [hit.event.ref!]);
      default:
    }
  }

  /// "Reminder from Mum: call me", when the member got to the place.
  Future<void> _showReminder(PlaceReminder r) async {
    final l = lookupAppL10n(await _locale());
    final name = r.fromName.isEmpty ? l.unnamedMember : r.fromName;
    final where = r.placeName == null
        ? null
        : r.onLeave
        ? l.reminderLeaving(r.placeName!)
        : l.reminderArriving(r.placeName!);
    try {
      await _channel.invokeMethod<void>('notify', {
        'id': r.id.hashCode & 0x3fffffff,
        'title': l.reminderFrom(name),
        'text': [?r.note, ?where].join(' · '),
        'quiet': false,
        'urgent': false,
        'channelName': l.alertsChannelName,
        'quietChannelName': l.alertsQuietChannelName,
        'urgentChannelName': l.sosChannelName,
      });
    } on MissingPluginException {
      // Tests.
    }
  }

  Future<void> _notify(AlertHit hit, AppL10n l) async {
    final name = hit.name.isEmpty ? l.unnamedMember : hit.name;
    final title = eventLine(l, name, hit.placeName, hit.event);
    final time = DateFormat.Hm(l.localeName).format(hit.event.at.toLocal());
    try {
      await _channel.invokeMethod<void>('notify', {
        'id': hit.notificationId,
        'title': title,
        'text': hit.event.note?.isNotEmpty == true
            ? '${hit.event.note} · ${l.alertAt(time)}'
            : l.alertAt(time),
        'quiet': hit.quiet && !hit.urgent,
        'urgent': hit.urgent,
        if (hit.asksMe) 'actionLabel': l.imOk,
        if (hit.asksMe) 'actionKind': 'checkin',
        if (hit.asksMe) 'actionSpace': hit.spaceId,
        'urgentChannelName': l.sosChannelName,
        'channelName': l.alertsChannelName,
        'quietChannelName': l.alertsQuietChannelName,
      });
    } on MissingPluginException {
      // Tests and platforms without the service.
    }
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

  /// Stops the service, unless alerts still need it (then it stays and
  /// stops taking positions).
  @override
  Future<void> stop() async {
    try {
      // The one service does both: it keeps running while this phone
      // still shares its location or still has alerts on.
      final sharing = (await engine.store.load())?.sharing ?? false;
      if (sharing || await _alertsOn()) {
        await _channel.invokeMethod<void>('start');
        return;
      }
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

  @override
  Future<bool> requestNotifications() async =>
      (await Permission.notification.request()).isGranted;

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
