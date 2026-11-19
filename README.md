# Zero-Trust Family

End-to-end encrypted family location sharing and safety check-ins (on the
phone: **ZT Family**). Same account, settings and look as the other Zero-Trust
apps, built on [Zero-Trust-Core](https://github.com/EdoSag/Zero-Trust-Core).
The server stores only ciphertext and can never see where anyone is.

> **Status: phase L3.** Family circles work (create, invite by link or QR
> code, join, leave), and each member can share their location with a
> circle, also while the phone is locked: an end-to-end encrypted position
> and battery level, on a battery-saving schedule, with pause and "Share
> live". Circles have places (Home, School), each phone works out its own
> arrivals and departures, and members can opt in to alerts that show while
> the app is locked, with quiet hours and a choice of whom to hear about.
>
> Members can check in ("I'm here", with a short note), ask someone to
> check in, and set a safety timer: if they don't tap "I'm OK" in time, the
> circle is alerted and sees them live for an hour, even if their phone is
> off (every reader's phone watches the deadline itself). SOS is sent by
> holding a button for 2 seconds; it rings past quiet hours and muting and
> shares live for an hour. History and the retention setting come in L4.

## What it will do

- **Family map:** everyone's last location, with accuracy, time since the
  last update, battery level and whether they are still, moving or paused.
- **Places:** Home, School, Work or any place, with arrive and leave alerts.
  Each phone watches the places itself, so the server never learns a place or
  a crossing.
- **Check-ins:** "I'm here", "Ask for a check-in", and a safety timer ("if I
  don't check in by 23:30, alert my family and share my live location").
- **SOS:** hold a button to alert the family circle with live location.
- **History:** a timeline per person, kept for a limited number of days and
  then deleted.
- **Pause:** anyone can pause sharing; the circle sees "Paused", never a fake
  location.

Not planned: hidden tracking of any kind, and screen time or app blocking.

## How it will be built

- A **family circle is a shared space** from Zero-Trust-Core (invite by link
  or QR code, signed member list, key rotation when someone is removed).
- **Sharing works while the app is locked.** The background service holds
  only the circle's public key and a device signing key kept in the Android
  Keystore: it can send location but cannot read anyone's.
- Arrive and leave alerts use Core's `zt_places` (Android `LocationManager`
  proximity alerts, no Google Play services), so it works on GrapheneOS.
- An adaptive schedule keeps battery use low: a check every 15 minutes when
  the phone is still, faster when it moves, live during an SOS or when
  someone is looking at the map.
- Map tiles are self-hosted (Protomaps PMTiles), so no third-party tile
  server sees which area a family is looking at.
- Every member is 13 or older, has their own account and turns sharing on
  from their own phone. A notification is always shown while sharing is on.

## Phases

| Phase | Scope |
|---|---|
| L0 | App shell on Core, family circle (create, invite, join, leave), database tables |
| L1 | Background sharing, battery schedule, family map, pause |
| L2 | Places with arrive and leave alerts |
| L3 | Check-ins, safety timer, SOS |
| L4 | History, Play Store declarations and listing, release checks |
| L5 | Drive summaries, crash detection, Wear OS SOS |
| L6 | iOS |

## Build

```bash
# .env (not committed; CI writes its own)
SUPABASE_URL=https://<project>.supabase.co
SUPABASE_ANON_KEY=<publishable key>
# Optional: a Protomaps v3 PMTiles file (self-hosted). Without it the circle
# shows no map, and "Show on map" opens the phone's maps app instead.
FAMILY_MAP_URL=https://<your tiles host>/<file>.pmtiles

flutter pub get
dart run zt_release_checks --app family   # shared release checks
flutter analyze && flutter test test/
flutter run
```

Flutter 3.47.9 (3.50 deprecates `material.dart` and fails analyze).

Pushing to `main` builds a signed APK and a Play bundle and publishes them as
a GitHub Release (`.github/workflows/android-apk.yml`). It needs the
repository secrets `ANDROID_KEYSTORE_BASE64` and `ANDROID_KEYSTORE_PASSWORD`,
the same keystore as the other Zero-Trust apps. Pull requests target `Dev`;
releases are one `Dev` → `main` pull request.

## How the code is laid out

- `lib/app/`: sign-in, lock and unlock (`app_gate.dart`), the app's id,
  colour and sharing rules (`family_config.dart`), links from account emails.
- `lib/data/family_data.dart`: circles as the screens see them, and every
  change the app makes.
- `lib/ui/`: home (circles, waiting joins), one circle, settings. Inviting,
  joining and the member list are the suite's shared screens
  (`zt_sharing_ui`).
- A circle's name is the item `family.circle` in its shared space, written
  by owners only. Items under `family.me/<user id>` can be written by that
  member alone.
- `lib/location/`: location sharing. `location_box.dart` (the circle's
  sealing key and the wire format), `schedule.dart` (how often to measure),
  `share_engine.dart` (seal, sign and upload one update per circle),
  `share_channel.dart` (the link to the Android service), `share_store.dart`
  (what the service may hold: public keys and the device key, in the
  Keystore).
- `android/.../ShareService.kt`: the foreground service of type location. It
  only measures (Android `LocationManager`, no Google Play services) and asks
  Dart what to do next. `FamilyApp.kt` keeps one Flutter engine for the
  screen and the service, so there is one signed-in Supabase client.
- Places are the space items `family.place/<id>` (any member can add one).
  `lib/location/geofence.dart` turns positions into arrivals and
  departures on the phone; each is a sealed row in `family_events`.
- `lib/location/alerts.dart`: alerts while locked (opt-in per circle). The
  phone keeps the circle's box seed (it opens only that circle's location
  data), the members' device keys and the names of people and places in the
  Keystore, reads new events when the service wakes or realtime says so,
  and `AlertNotifier.kt` shows them.
- `lib/data/locations.dart`: opening a circle's locations (only rows signed
  by a device its member published), and turning sharing on, off, paused or
  live. Each sharing phone publishes its device key as the item
  `family.me/<user id>/device/<device id>`.
- The location tables (`family_latest`, `family_events`) are in
  Zero-Trust-Core, `supabase/migrations/20261118120000_family_location_tables.sql`.

## License

AGPL-3.0. See [LICENSE](LICENSE).
