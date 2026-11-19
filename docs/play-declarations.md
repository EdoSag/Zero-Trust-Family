# Google Play declarations for ZT Family

These are the answers to paste into the Play Console for `dev.sagron.zerotrustfamily`. They match what the app does in L0 to L4. Update them when a feature changes how location is used.

## 1. Location permissions (App content > Sensitive app permissions > Location)

**Does your app access location in the background?** Yes.

**Core feature that uses background location (one feature):**
Family location sharing. Each person who turns on sharing in a family circle sends their location, end-to-end encrypted, to the people in that circle while the app is closed. The circle uses it to see where family members are, to get "arrived at / left" alerts for places like Home and School, and to see a person live after an SOS or a missed safety timer.

**Why the feature needs background location (paste as is):**
> ZT Family is a family safety app. A person who chooses to share their location with their family circle keeps sharing it while the app is closed, so that family members can see where they are, get arrival and departure alerts for places they set (Home, School), and find them after an SOS or a missed safety check-in. Without background location, family members would only see a location while the app is open on the sharing phone, which defeats the purpose. Sharing is off by default, is turned on per circle by the person themselves after an in-app explanation, shows a persistent notification while active, and can be paused or stopped at any time. Locations are end-to-end encrypted: neither the developer nor the server can read them.

**Prominent disclosure:** shown before Android's permission prompt, when the person turns sharing on for a circle (the dialog with `share-consent-continue`, string `shareConsentBody`). It says the app collects location to share it with the circle, also when the app is closed or not in use, that history is kept for the circle's window, and that a notification shows while sharing.

**Video (30 seconds or less, upload unlisted to YouTube):**
1. Open a circle and turn on sharing.
2. Show the in-app disclosure, tap Continue.
3. Android asks for location: choose "While using the app", then "Allow all the time" in settings.
4. Lock the phone. Show the "Sharing your location" notification.
5. On a second phone, show the first phone's position updating on the map, and an "arrived at Home" alert.

## 2. Foreground service (App content > Foreground service permissions)

| Type | Permission | Feature | User-visible |
|---|---|---|---|
| `location` | `FOREGROUND_SERVICE_LOCATION` | Family location sharing (above) | Yes: persistent "Sharing your location" notification while sharing is on |

Started only when the person turns sharing on, or after a reboot or update if sharing was on. It stops when sharing is off in every circle. Video: the same video as above (steps 4 and 5).

## 3. Other sensitive permissions

| Permission | Why |
|---|---|
| `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION` | Sharing, and "use my current location" when adding a place |
| `ACCESS_BACKGROUND_LOCATION` | Sharing while the app is closed (section 1) |
| `CAMERA` | Scanning an invite QR code (only when the person taps Scan) |
| `POST_NOTIFICATIONS` | The sharing notification, arrival alerts, check-in requests, SOS |
| `RECEIVE_BOOT_COMPLETED` | Restart sharing after a reboot, if it was on |
| `WAKE_LOCK` | Send a position before the phone sleeps again |
| No exact alarms | The safety timer uses `setAndAllowWhileIdle`, which needs no special permission |

## 4. Stalkerware and monitoring policy

ZT Family is not monitoring software. Every person installs it on their own phone, signs in with their own account, and chooses to share for themselves. It can't be hidden: the launcher icon stays, and a persistent notification shows whenever location is shared. Anyone can pause or stop at any time, and can leave a circle. The listing says this, and the minimum age is 13.

## 5. Data safety form

| Data type | Collected | Shared | Notes |
|---|---|---|---|
| Location: precise | Yes | No | End-to-end encrypted; only circle members can decrypt. Optional (only when sharing is on). Purpose: app functionality. |
| Location: approximate | Yes | No | Same as precise. |
| Personal info: email address | Yes | No | Account sign-in. Required. Purpose: account management. |
| Personal info: name | Yes | No | The name shown to the circle, end-to-end encrypted. Optional. |
| App activity: other user-generated content | Yes | No | Places, check-in notes; end-to-end encrypted. Optional. |
| Device or other IDs | No | | A random per-install device id is used only to sign location rows. |
| Battery level | (not a Play data type) | | Sent with each location, end-to-end encrypted. |

- **Is all data encrypted in transit?** Yes (TLS, plus end-to-end encryption).
- **Can users request data deletion?** Yes: in the app (Settings > Account > Delete account, and "Erase my history in this circle") and at support@zerotrust.bz.
- **Is data processed ephemerally?** No. Positions are kept on the server, encrypted, for the circle's history window (7 days by default, up to 30 with Plus), then deleted. The latest position is deleted when sharing stops or after 30 days of silence.

## 6. Target audience and content

- Target age: 13 and up (not designed for children under 13).
- Category: Lifestyle (or Parenting). Tags: family locator, safety.
- Ads: none.
