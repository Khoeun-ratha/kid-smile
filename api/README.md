# Kid Smile — API (FastAPI)

Stores quiz categories/questions and serves versioned "packs" that the
Flutter app pulls down when it's online. Reads are open; writes need the
admin bearer token (`ADMIN_TOKEN` env var, defaults to `change-me`).

## Run

```
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
python -m app.seed          # populates starter categories/questions
uvicorn app.main:app --reload
```

API docs at http://127.0.0.1:8000/docs.

## Key endpoint

`GET /pack?since_version=N` — returns the full pack (`{version, categories,
questions}`) if the server's version is newer than `N`, otherwise `204`. This
is the only endpoint the mobile app calls; everything else is for the admin
dashboard.

`POST /publish` (admin) bumps the pack version once edits are ready, so
mobile devices pick up a batch of changes together.

## Test

```
pytest
```
