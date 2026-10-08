# Kid Smile

An offline-first quiz app for kids, with a small admin dashboard for
managing the question bank.

- **`mobile/`** — Flutter app kids actually play. Fully offline via a
  bundled seed pack + local SQLite; syncs new content from the API in the
  background when online.
- **`api/`** — FastAPI backend storing categories/questions, serving
  versioned "packs" to mobile.
- **`web/`** — Vue 3 admin dashboard for editing quiz content and
  publishing new pack versions.

See [PLAN.md](PLAN.md) for the full step-by-step build plan and
architecture rationale, and each folder's own README for how to run it.

## Quick start (all three, for local dev)

```
# 1. API
cd api
python -m venv .venv && .venv\Scripts\activate
pip install -r requirements.txt
python -m app.seed
uvicorn app.main:app --reload

# 2. Web admin (new terminal)
cd web
npm install
npm run dev

# 3. Mobile (new terminal)
cd mobile
flutter pub get
flutter run
```

The mobile app works immediately even with steps 1–2 skipped — it ships
with its own seed data and only needs the API for picking up *new* content
later.
