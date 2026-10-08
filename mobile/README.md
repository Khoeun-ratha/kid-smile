# Kid Smile — mobile (Flutter)

Offline-first quiz app for kids. Works fully offline from first launch using a
bundled seed question pack. Builds given an `API_URL` also sync newer content
from the API (`../api`) when a network connection is available.

## Run

```
flutter pub get
flutter run                          # offline-only: bundled questions, no server
flutter build apk --release          # offline-only release
```

By default the app is **offline-only**: it plays the bundled packs from local
SQLite, never contacts a server, and hides "Check for new questions". If a
device previously synced from a server, an offline build restores the full
bundled packs on next launch.

To turn on sync, pass the API address at build time:

```
flutter run --dart-define=API_URL=http://192.168.8.169:8000      # dev API on the LAN
flutter build apk --release --dart-define=API_URL=https://<api-host>
```

An Android emulator reaches your machine's `localhost` via `10.0.2.2`. Plain
`http://` only works for the hosts listed in
`android/app/src/main/res/xml/network_security_config.xml`.

Before pointing a sync build at a server, make sure that server holds the
full question set: a sync **replaces** the device's questions for that
language with whatever the server has.

## Structure

- `lib/models/` — Category, Question, QuestionPack
- `lib/data/` — `db_helper.dart` (SQLite schema + seed/import),
  `pack_repository.dart` (the only thing screens talk to for content)
- `lib/services/sync_service.dart` — best-effort background sync with the API
- `lib/logic/quiz_engine.dart` — random question selection, choice shuffling,
  scoring (pure Dart, unit tested)
- `lib/screens/` — Splash → Home (categories) → Quiz → Result, + Settings

## Test

```
flutter test
```

Includes unit tests for the quiz engine's shuffling/scoring and a smoke test
that boots the app to the splash screen.
