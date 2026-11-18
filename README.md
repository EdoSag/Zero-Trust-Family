# Zero-Trust Family

End-to-end encrypted family location sharing and safety check-ins (on the
phone: **ZT Family**). Same account, settings and look as the other Zero-Trust
apps, built on [Zero-Trust-Core](https://github.com/EdoSag/Zero-Trust-Core).
The server stores only ciphertext and can never see where anyone is.

> **Status: planned, not built yet.** This repository holds the starting
> point. The first code lands with phase L0 below.

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

## Contributing

Pull requests target the `Dev` branch. Releases are one `Dev` → `main` pull
request; pushing to `main` will build a signed APK with the same keystore
secrets as the other Zero-Trust apps (`ANDROID_KEYSTORE_BASE64`,
`ANDROID_KEYSTORE_PASSWORD`) once the release workflow is added in L0.

## License

AGPL-3.0. See [LICENSE](LICENSE).
