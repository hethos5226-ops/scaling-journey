# Scaling Journey

A private, photo-focused body-weight progress journal for iOS.

The idea the whole app is built around: **weight, photo and date belong
together**. Everything else follows from keeping those three connected.

---

## Getting started

Requires **Xcode 16 or later** and **iOS 17+**.

```bash
git clone https://github.com/hethos5226-ops/scaling-journey.git
cd scaling-journey
open ScalingJourney.xcodeproj
```

Select the `ScalingJourney` scheme and run. No configuration, backend or
account is needed — the app is fully functional offline out of the box.

### Optional configuration

Signing details and future integration keys live in a gitignored file:

```bash
cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig
```

Fill in what you need (`DEVELOPMENT_TEAM`, `APP_BUNDLE_IDENTIFIER_BASE`,
later `SJ_API_BASE_URL` and `SJ_GOOGLE_CLIENT_ID`). `Config/Base.xcconfig`
pulls it in with an optional `#include?`, so a fresh clone still builds
with the defaults.

**No secret is ever committed.** `Config/Secrets.xcconfig` is in
`.gitignore`, and `Scripts/validate_sources.py` fails if it appears in the
working tree.

### Tests

```bash
xcodebuild test -scheme ScalingJourney -destination 'platform=iOS Simulator,name=iPhone 16'
python3 Scripts/validate_sources.py   # static checks, no toolchain needed
```

---

## Architecture

```
ScalingJourney/
  App/            Composition root, tab navigation, the observable app store
  Core/
    Models/       SwiftData models + Sendable value-type snapshots
    Persistence/  Versioned schema, container factory, repositories
    Photos/       PhotoStore protocol, file-backed store, image processing
    Auth/         Authentication protocol, device-local implementation
    Sync/         SyncEngine protocol (no-op today)
    Units/        Mass units, formatting, parsing
    Stats/        Pure statistics and range filtering
    Config/       Build-time configuration
  DesignSystem/   Tokens and shared components
  Features/       Home, LogEntry, Progress, Calendar, Settings
```

### Decisions worth knowing

**Weight is always stored in kilograms.** Kilograms, pounds and stones are
a display preference. Switching units never rewrites a record and never
accumulates rounding drift. Stones display as `12 st 4.2 lb` but are
*entered* in pounds, because nobody types "12.3 st" on a keypad.

**Photos are never stored in the database.** `ProgressPhoto` holds an
opaque identifier; `PhotoStore` resolves it to bytes. `FilePhotoStore`
writes a downscaled JPEG plus a thumbnail into Application Support,
excluded from backup and protected until first unlock. Swapping in object
storage later is a change to the composition root, not a migration.

**Value-type snapshots isolate the UI from SwiftData.** Views, statistics
and (later) charts work with `WeightEntrySnapshot`, so `ProgressStatistics`
is testable with plain literals and carries no framework dependency.

**One observable store.** `JourneyStore` holds the whole entry list in
memory — a person logging daily for five years has under 2,000 small rows.
Every screen recomputes instantly and stays consistent, and a sync engine
has one place to publish into.

**Everything is sync-ready from day one.** Every model carries
`remoteID`, `updatedAt`, `syncState`, and deletes are tombstones rather
than removals, so a delete on one device cannot be resurrected by a peer.
Turning on a backend is additive.

**Accounts are optional, not absent.** `AuthenticationService` already
describes Apple, Google, email and account deletion. Phase 1 ships a
device-local account keyed by a Keychain identifier that a real account can
later adopt, so no existing data is orphaned when sign-in arrives. A
sign-in wall before the user has logged a single weight is the fastest way
to lose them.

**HealthKit is designed for, not depended on.** Entries carry a `source`
and an `externalIdentifier`, so imports stay idempotent whenever they land.

---

## Status

**Phase 1 (done)** — architecture, persistence, photo storage, auth
seam, four-tab navigation, Home, and the full weight + photo + date
logging flow.

**Next** — the weight chart on Progress, tapping a point to open its
entry, then the photo timeline and before/after comparison.

**Later** — CSV import, historical photo matching, cloud accounts and
sync, data export and account deletion, HealthKit, body measurements,
widgets and reminders.

---

## Privacy

Progress photos are among the most personal things a person can record.
They stay in the app's private storage, out of the photo library, out of
device backups, and off the network. There are no profiles, no feeds and
no sharing. Nothing leaves the device unless the user exports it.
