# Zero-Trust Family

End-to-end encrypted family location sharing and safety check-ins. The
server stores only ciphertext and can never see where anyone is. On the
phone it is called **ZT Family**; in stores and on release pages,
**Zero-Trust Family**. Same account, settings and look as the other
Zero-Trust apps, built on
[Zero-Trust-Core](https://github.com/EdoSag/Zero-Trust-Core). Part of the
[Zero-Trust suite](https://zerotrust.bz).

## What it does

- **Family circles:** create a circle, invite people by link or QR code,
  join, leave.
- **Family map:** everyone's last location, with accuracy, time since the
  last update, battery level and whether they are still, moving or paused.
  Sharing works while the phone is locked, on a battery-saving schedule,
  with "Share live".
- **Places:** Home, School, Work or any place, with arrive and leave
  alerts. Each phone works out its own arrivals and departures, so the
  server never learns a place or a crossing. Alerts are opt-in, show while
  the app is locked, and have quiet hours and a choice of whom to hear
  about.
- **Check-ins:** "I'm here" with a short note, "Ask for a check-in", and a
  safety timer: if you don't tap "I'm OK" in time, the circle is alerted
  and sees you live for an hour, even if your phone is off (every reader's
  phone watches the deadline itself).
- **SOS:** hold a button for 2 seconds. It rings past quiet hours and
  muting and shares live for an hour.
- **History:** each member's stops, trips, check-ins and alerts, a day at a
  time, for as long as the circle keeps it (7 days by default, chosen by
  the owner). Anyone can erase their own history.
- **Pause:** anyone can pause sharing; the circle sees "Paused", never a
  fake location.
- **Approximate location** (per circle, on each phone): positions to that
  circle are snapped to a grid cell about 3 km across. An SOS or a missed
  safety timer always sends the exact position.
- **Place reminders for someone else:** a reminder shown on a member's
  phone when they arrive at or leave a place.
- **Share my trip:** a link that shows your position for 1, 2 or 4 hours
  to someone without the app (`https://zerotrust.bz/trip/#…`). The key is
  in the part of the link that never reaches a server.
- **Drive summaries and crash detection** (opt-in): distance, speed, hard
  braking and phone use for each drive, kept on the phone. After a hard
  jolt at speed followed by a stop, the phone rings for 60 seconds and
  then sends an SOS to every circle unless you tap "I'm OK". It can miss a
  crash or ring when there was none, and it does not call emergency
  services.
- **Family hub:** the circle is also the family space of the other apps.
  It shows, read-only, events from ZT Calendar, task lists from ZT Tasks
  and today's doses from ZT Meds that members chose to show there.

Safety is always free: the map, places, alerts, check-ins, the safety
timer, SOS and 7 days of history. Plus adds more than 5 places, up to 30
days of history and sharing drive summaries with a circle.

Not planned: hidden tracking of any kind, and screen time or app blocking.
Not built yet: iOS, and SOS from a Wear OS watch.

## Privacy

Like every Zero-Trust app, it is zero-knowledge: your data is encrypted on
your device, with keys made from your password, before anything is sent.
The server stores only ciphertext and your password itself is never
sent, so neither we nor anyone who breaks into the server can read your
data. The recovery key shown at sign-up is the only way back in if you
forget the password. How the keys work:
[Zero-Trust-Core](https://github.com/EdoSag/Zero-Trust-Core#key-hierarchy) and
[zerotrust.bz/security](https://zerotrust.bz/security/).

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

## One account, one core

One Zero-Trust account opens every app in the suite. Sign-in, unlock
(fingerprint or face, auto-lock), the recovery key, settings, the look,
sync and languages come from
[Zero-Trust-Core](https://github.com/EdoSag/Zero-Trust-Core), so they work
the same in every app. Accounts made before the core still sign in and
see their data.

## Install

Android: get the latest signed APK from this repository's
[Releases](https://github.com/EdoSag/Zero-Trust-Family/releases/latest),
or from [zerotrust.bz/install](https://zerotrust.bz/install/#family),
which also shows each file's SHA-256, the signing fingerprint and an
Obtainium link. GitHub Releases are the main way the apps are published.

Builds from GitHub check for a newer release themselves (Settings > About,
one anonymous request a day, can be turned off). Every Zero-Trust app is signed
with the same key, and Android only installs an update signed with it.

## Languages

English and Hebrew, with right-to-left layout. Choose under
Settings > Appearance > Language.

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
- `lib/location/drive.dart`: drive summaries and crash detection (opt-in,
  L5). While the phone is driving, `ShareService.kt` takes one sample a
  second (satellite speed and position, the hardest accelerometer jolt,
  whether the phone was in use) and sends them in batches. `DriveTracker`
  turns them into drive summaries (kept on the phone in the Keystore,
  `drive_store.dart`, and sent as sealed `drive` events only to circles the
  driver chose); `CrashDetector` looks for a hard jolt at speed followed by
  a stop, then the phone rings for 60 seconds and sends an SOS to every
  circle unless the driver taps "I'm OK".
- `lib/location/approximate.dart`: approximate sharing (L-5), per circle on
  each phone. Positions to that circle are snapped to the centre of a grid
  cell about 3 km across (no speed or heading), so repeated updates can't be
  averaged into the real spot. An SOS or missed safety timer always sends
  the exact position, and while an SOS runs every circle gets it.
- `lib/location/reminders.dart`: place reminders for someone else (L-4).
  A reminder is a sealed `remind` event addressed to one member; their
  phone keeps the open ones in the share store (picked up when the app is
  opened, or while locked when alerts are on) and shows it when the
  geofence sees them arrive at or leave the place, then sends `remindDone`
  to whoever set it. `remindCancel` takes one back. Only the member can
  close it as done, and only the sender or the member can take it back.
- `lib/location/trip_share.dart`: "Share my trip" links (L-1). The phone
  makes a random id and AES-256-GCM key; the link is
  `https://zerotrust.bz/trip/#<id>.<key>`, so the key never reaches a
  server. While the trip runs (1, 2 or 4 hours) each update is sealed under
  it and put in `family_trip_shares`; the website's trip page reads it with
  `family_trip_get(id)` and opens it in the browser. Stopping, a new trip,
  or turning sharing off deletes the row; the server ignores and purges
  ended ones.
- `lib/model/family_hub.dart`, `lib/ui/hub_page.dart`: the family hub
  (L-2). Since S-10 the circle is every app's family space: ZT Calendar,
  ZT Tasks and ZT Meds keep their family items in it as
  `<app>/<kind>/<id>` with a common summary under `zt`
  (`ZtFamilySummary` in Core). The hub reads those summaries, read-only:
  events of the next 14 days, task lists with their open items, today's
  doses, and anything else. The circle is checked with Core's
  `ZtFamilySpace.policy`, the same in every app.
- The location tables (`family_latest`, `family_events`) are in
  Zero-Trust-Core, `supabase/migrations/20261118120000_family_location_tables.sql`;
  trip links in `20261123090000_family_trip_shares.sql`.

## Build from source

Flutter 3.47.9, the version CI pins (3.50 deprecates `material.dart` and
fails analyze).

First create a file named `.env` in the project folder. It is not committed
(CI writes its own) and it is bundled into the APK, so it holds public client
values only, never a service-role key:

```
SUPABASE_URL=https://<project>.supabase.co
SUPABASE_ANON_KEY=<publishable key>
# Optional: a Protomaps v3 PMTiles file (self-hosted). Without it the circle
# shows no map, and "Show on map" opens the phone's maps app instead.
FAMILY_MAP_URL=https://<your tiles host>/<file>.pmtiles
```

Then:

```bash
flutter pub get
dart run zt_release_checks --app family   # shared release checks
flutter analyze && flutter test test/
flutter run
```

Never add `cryptography_flutter`: it breaks the core's key derivation and
sign-in fails.

## Branches and releases

Work happens on `Dev`: pull requests target `Dev`, never `main`, and get a
test build. A release is one `Dev` → `main` pull request. Every push to
`main` runs the suite's release checks, builds a signed APK and a Google Play bundle
and publishes them as a GitHub Release named "Zero-Trust Family"
(`.github/workflows/android-apk.yml`). The workflow needs the repository
secrets `ANDROID_KEYSTORE_BASE64` and `ANDROID_KEYSTORE_PASSWORD`, the
keystore shared by all Zero-Trust apps.

Play listing text is in `fastlane/` and the Play Console answers in
`docs/play-declarations.md`.

## Support and security

- Help centre: [zerotrust.bz/help](https://zerotrust.bz/help/). Questions and
  account deletion: support@zerotrust.bz.
- Security problems: please report them privately to cyber@zerotrust.bz. What
  the encryption does and doesn't protect against is on
  [zerotrust.bz/security](https://zerotrust.bz/security/).
- [Privacy policy](https://zerotrust.bz/privacy/) and
  [terms](https://zerotrust.bz/terms/).

## License

Copyright (C) 2026 Edo Sagron (https://zerotrust.bz)

Zero-Trust is open source under the [GNU Affero General Public License v3.0](LICENSE)
(AGPL-3.0-only), the same licence Signal uses.

- You may use, study, change and share the code, including in your own projects.
- If you share a changed version, or run it for other people over a network, you must
  publish your full source code under the same licence.
- This program comes with no warranty; see the licence for details.

Third-party libraries keep their own licences; the app lists them under
Settings > Open-source licences.

### Name and logo

The AGPL covers the code, not the brand. "Zero-Trust", "ZT", the app names and icons are
reserved. If you publish a fork, give it a different name and icon so nobody mistakes it
for an official Zero-Trust app.

### Servers

The official apps use the Zero-Trust servers. A fork must use its own backend (for
example its own Supabase project) and must not connect to the official servers.

### Contributing

Pull requests are welcome. By sending one you agree that your contribution is licensed
under the AGPL-3.0 and that the copyright holder may also license it under other terms,
including commercially. This keeps the project able to offer paid plans and other licences.
