# Kid Smile — mobile (Flutter)

Offline-first quiz app for kids. Works fully offline from first launch using a
bundled seed question pack, and silently syncs newer content from the API
(`../api`) when a network connection is available.

## Run

```
flutter pub get
flutter run
```

No backend needs to be running — the app plays entirely from local SQLite.
To test the sync path, start the API (`../api/README.md`) and run on an
Android emulator, which reaches your machine's `localhost` via `10.0.2.2`
(already the default `baseUrl` in `lib/services/sync_service.dart`). For a
physical device or iOS simulator, change `baseUrl` to your machine's LAN IP.

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
