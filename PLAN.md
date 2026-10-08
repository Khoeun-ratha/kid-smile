# Kid Smile — Offline Kids Quiz App: Full Build Plan

One monorepo, three parts:

```
kid_smile/
├── mobile/   Flutter app — the kids' quiz, works fully offline
├── web/      Vue 3 admin dashboard — content managers create/edit questions
├── api/      Python (FastAPI) backend — stores questions, serves "packs" to mobile
└── docs/     supporting docs
```

## Why this architecture

Kids need the quiz to work with zero connectivity (car rides, planes, spotty wifi).
So the mobile app never depends on a live network call during play:

1. Questions ship as a **local seed pack** bundled in the app (works offline from
   first launch, no setup needed).
2. When the device *does* have internet, the app silently checks the API for a
   newer **question pack version** and downloads/merges it into local SQLite.
3. All quiz play, shuffling, and scoring happens **entirely against local
   SQLite** — the network is only ever used for content updates, never for
   gameplay.
4. The Vue dashboard + Python API exist purely so a non-technical adult can add
   new questions/categories without shipping an app update — they publish a
   new pack version, and mobile picks it up next time it's online.

This is the standard "offline-first with background sync" pattern — simplest
version of it, no conflict resolution needed since mobile is read-only for
content (kids don't edit questions, only answer them).

---

## Part 1 — Data model (shared concept across all 3 apps)

- **Category**: id, name, icon/emoji, color, sort_order
- **Question**: id, category_id, prompt text, 4 choices, correct_choice_index,
  optional image_url, difficulty (easy/medium/hard), age_group (4-6/7-9/10-12)
- **Pack**: a versioned export of all categories+questions
  (`{ version: int, generated_at, categories: [...], questions: [...] }`)
- **QuizAttempt** (mobile-local only): category_id, score, total, played_at —
  powers a simple local history/stars screen, never synced anywhere (no kid
  accounts, no PII leaves the device)

---

## Part 2 — Python API (`/api`)

Step-by-step:

1. **Scaffold**: FastAPI + SQLAlchemy + SQLite (swap to Postgres later by
   changing one env var — no code change needed).
2. **Models**: `Category`, `Question` tables via SQLAlchemy.
3. **Schemas**: Pydantic request/response models.
4. **Seed script**: `seed.py` inserts a starter set of categories (Animals,
   Colors, Numbers, Shapes, Nature) with ~5 questions each, so the API is
   demoable immediately.
5. **CRUD routers**:
   - `GET/POST/PUT/DELETE /categories`
   - `GET/POST/PUT/DELETE /questions`
   - Simple bearer-token admin auth (one shared admin token via env var — no
     need for full user management at this scale) guarding writes; reads are
     open so mobile can fetch without auth.
6. **Pack endpoint**: `GET /pack?since_version=N` — returns the full current
   pack if the server's version is newer than `since_version`, else `304`-style
   "no update" response. This is the single endpoint the Flutter app calls.
7. **Versioning**: bump a `pack_version` row every time content changes
   (simple integer counter in a `meta` table), so mobile can cheaply check
   "is there anything new" with one small request.
8. **Run**: `uvicorn app.main:app --reload` for local dev.
9. **Tests**: pytest hitting the CRUD + pack endpoints with an in-memory
   SQLite DB.
10. **Deploy** (later, not needed for offline-first play): any container host
    (Fly.io/Render/a small VPS) + persistent volume for the SQLite file, or
    swap to managed Postgres.

## Part 3 — Vue web admin (`/web`)

Step-by-step:

1. **Scaffold**: Vite + Vue 3 + Vue Router + Pinia + a simple CSS framework
   (or plain CSS — kids'-app-adjacent admin doesn't need to be fancy).
2. **Login page**: enters the shared admin token, stored in memory/session
   (not localStorage, to avoid leaving it lying around) and attached as
   `Authorization: Bearer <token>` on API calls.
3. **Categories page**: table + create/edit/delete form, calls the API's
   `/categories` CRUD.
4. **Questions page**: table filterable by category, create/edit/delete form
   with 4 choice inputs + "which is correct" radio + image URL field.
5. **Publish button**: calls a `/publish` endpoint (bumps `pack_version`) once
   an admin is happy with their edits, so mobile devices pick up the batch of
   changes together rather than one-by-one.
6. **Preview pane**: renders a question the way it'll look on a phone, so
   non-technical admins can sanity-check before publishing.
7. **Build/deploy**: `npm run build` → static hosting (Netlify/Vercel/S3),
   pointed at the deployed API's URL via an env var.

## Part 4 — Flutter mobile app (`/mobile`) — the core deliverable

Step-by-step:

1. **Scaffold**: `flutter create mobile`, targeting Android + iOS.
2. **Packages**: `sqflite` (local DB), `path_provider`, `http` (sync calls),
   `connectivity_plus` (know when it's safe to try syncing),
   `shared_preferences` (store current pack_version + settings),
   `provider` (state mgmt — simplest option for this scope),
   `audioplayers` (correct/wrong sound effects — delight for kids),
   `confetti` or similar (celebratory animation on good scores).
3. **Seed asset**: `assets/seed_pack.json` — same shape as the API's `/pack`
   response, bundled at build time so day-one installs work with zero network
   and zero setup.
4. **Local DB layer** (`lib/data/`):
   - `db_helper.dart`: opens/creates SQLite tables mirroring Category/Question.
   - On first launch (empty DB), import `seed_pack.json`.
   - `pack_repository.dart`: exposes `getCategories()`,
     `getRandomQuestions(categoryId, count)`, `savePack(pack)` (used both by
     seed import and by sync merges — same code path).
5. **Sync service** (`lib/services/sync_service.dart`):
   - On app start (and on manual "refresh" pull), if `connectivity_plus`
     reports online, call `GET {API_URL}/pack?since_version=<local version>`.
   - If server returns a newer pack, replace local categories/questions in a
     single transaction and update the stored version.
   - Runs silently in the background; play is never blocked on this.
6. **Random quiz engine** (`lib/logic/quiz_engine.dart`):
   - Given a category (or "Mixed" across all categories), pick N random
     questions without repeats (`Random().shuffle` on the id list, or SQL
     `ORDER BY RANDOM() LIMIT N`).
   - Shuffle each question's 4 choices independently so the correct answer
     isn't always in the same visual slot.
   - Track score as the kid answers.
7. **Screens** (`lib/screens/`):
   - `SplashScreen`: seeds DB if needed, then routes to Home.
   - `HomeScreen`: big colorful category tiles (icon + name) + a "Mixed
     Quiz" tile; shows a small sync-status dot (green = up to date, grey =
     offline, spinning = syncing).
   - `QuizScreen`: one question at a time, 4 large tappable choice buttons,
     immediate visual+sound feedback (correct = green flash + happy sound,
     wrong = gentle shake + show correct answer), auto-advance after a short
     delay, progress bar (e.g. "3/10").
   - `ResultScreen`: score, stars rating, "Play Again" / "Home" buttons,
     simple animation (confetti) for high scores.
   - `HistoryScreen` (optional stretch): list of past attempts from local DB.
   - `SettingsScreen`: sound on/off, manual "Check for new questions" button,
     app version.
8. **Kid-friendly UI polish**: large tap targets, bright rounded buttons, a
   playful font (Google Fonts e.g. "Baloo 2" or "Fredoka"), minimal text (icons
   + short words), no dead-ends (every screen has an obvious big button
   forward).
9. **Testing**: widget tests for `QuizScreen` answer flow; unit tests for
   `quiz_engine.dart` randomization and scoring logic.
10. **Build**: `flutter build apk` / `flutter build ios` for release binaries.

---

## Part 5 — Build order (recommended sequence)

1. Flutter app with the **seed JSON only**, no API/sync yet → fully playable
   offline quiz, demoable in under a day.
2. Python API with seed data + `/pack` endpoint.
3. Wire the Flutter `sync_service` to that API.
4. Vue admin so content can be edited without touching code.
5. Polish: sounds, animations, history screen, settings.

---

## Part 6 — What's already scaffolded in this repo

- `mobile/` — Flutter project created, dependencies added, offline data
  layer + quiz engine + all 5 core screens implemented and wired to a
  bundled seed pack. Runs fully offline out of the box.
- `api/` — FastAPI app with Category/Question models, CRUD routers, seed
  script, and the `/pack` sync endpoint.
- `web/` — Vue 3 + Vite admin scaffold with login, categories, and
  questions management calling the API.

See each folder's own README for how to run it.
