# Kid Smile — Build Progress Checklist

Legend: `[x]` done and verified · `[ ]` not started / still to do

---

## Part 0 — Repo setup

- [x] Monorepo folders created: `mobile/`, `api/`, `web/`
- [x] `PLAN.md` written (full architecture + step-by-step plan)
- [x] Root `README.md` with quick-start for all three apps

---

## Part 1 — Data model

- [x] Category shape defined (id, name, icon, color, sort_order)
- [x] Question shape defined (id, category_id, prompt, 4 choices, correct_index, difficulty, age_group)
- [x] Pack shape defined (version, categories[], questions[]) — same shape used by seed JSON, API response, and mobile SQLite import
- [x] QuizAttempt (mobile-local only) — score, total, played_at

---

## Part 2 — Python API (`/api`)

- [x] Scaffold: FastAPI + SQLAlchemy + SQLite
- [x] Models: `Category`, `Question`, `Meta` (pack_version)
- [x] Pydantic schemas
- [x] Seed script (`python -m app.seed`) — verified: seeds 5 categories, 26 questions
- [x] CRUD routers: `/categories`, `/questions` (GET open, POST/PUT/DELETE admin-token-gated)
- [x] `/pack?since_version=N` sync endpoint — verified returns full pack or `204`
- [x] `/publish` endpoint bumps pack_version — verified
- [x] `/admin/check` endpoint for the web login to validate a token with no side effects
- [x] Runs locally (`uvicorn app.main:app --reload`) — verified live: `/health`, auth reject/accept, CORS preflight all checked by hand
- [x] Tests: `pytest` — **11/11 passing**
- [ ] **Deploy to a real host** (Fly.io / Render / VPS) — not done, only run locally so far
- [ ] Switch `DATABASE_URL` to Postgres for production (currently SQLite file, fine for local/dev)

## Part 3 — Vue web admin (`/web`)

- [x] Scaffold: Vite + Vue 3 + Vue Router + Pinia
- [x] Login page (token kept in memory only, not localStorage)
- [x] Categories page: list + create/edit/delete
- [x] Questions page: list + create/edit/delete, filter by category
- [x] Publish button (bumps API pack_version)
- [x] Preview pane (shows question + highlights correct choice while editing)
- [x] `npm run build` — verified, builds clean
- [ ] **Deploy** (Netlify/Vercel/static host) — not done, only run locally (`npm run dev`) so far
- [ ] Manually click through the UI in a browser against a running API (build was verified, but no one has clicked every button yet)

## Part 4 — Flutter mobile app (`/mobile`) — core deliverable

- [x] `flutter create` scaffold
- [x] Dependencies added: sqflite, path_provider, http, connectivity_plus, shared_preferences, provider, google_fonts, confetti
- [x] Seed asset bundled (`assets/seed_pack.json`)
- [x] Local DB layer (`db_helper.dart`, `pack_repository.dart`) — create tables, import pack, seed on first run
- [x] Sync service — calls API `/pack`, merges newer content, fails silently offline
- [x] Random quiz engine — random question pick, shuffled choices, scoring — **unit tested**
- [x] Screens: Splash, Home, Quiz, Result, Settings
- [x] Kid-friendly styling (rounded buttons, Baloo 2 font, bright category colors, confetti on good scores)
- [x] `flutter analyze` — clean, no issues
- [x] `flutter test` — **4/4 passing** (3 engine tests + 1 boot smoke test)
- [ ] **Run on an actual emulator/device** (`flutter run`) — not done yet in this environment (no emulator attached); analyzer/tests pass but nobody has tapped through the live app
- [ ] Verify sync against a running API from a real Android emulator (`10.0.2.2`) or physical device (needs LAN IP change)
- [ ] Sound effects — intentionally skipped for now (kept scope to visual/haptic feedback); add `audioplayers` + sound assets later if wanted
- [ ] History screen (listed as optional/stretch in the plan) — not built
- [ ] Release builds: `flutter build apk` / `flutter build ios` — not done

## Part 5 — Full offline↔online loop, end to end

- [x] Mobile plays fully offline from the bundled seed pack — verified via unit/widget tests
- [x] API `/pack` versioning logic verified via automated tests + manual curl
- [ ] **Full live loop not yet exercised together**: admin edits a question in the web dashboard → clicks Publish → mobile app (running on a real device/emulator) picks it up via sync. Each piece is tested in isolation; this cross-app path hasn't been run end-to-end yet.

---

## What's genuinely left before this is a "real" shipped product

1. Run the mobile app on an emulator or your phone and play through it (`cd mobile && flutter run`)
2. Run the API and web admin together and click through creating/editing a question and hitting Publish
3. Point the mobile app's `SyncService.baseUrl` at that running API and confirm a published change shows up after a manual "Check for new questions" tap
4. Decide on hosting for the API + web admin, and deploy
5. Build real release binaries (`flutter build apk`, `flutter build ios`) when ready to distribute
