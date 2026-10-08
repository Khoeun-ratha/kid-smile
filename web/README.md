# Kid Smile — web admin (Vue 3 + Vite)

Dashboard for a non-technical adult to manage quiz categories/questions
without shipping a mobile app update. Talks to the API (`../api`); the
mobile app never talks to this directly.

## Run

```
npm install
npm run dev
```

Requires the API running (`../api/README.md`) at the URL in `.env`
(`VITE_API_URL`, defaults to `http://127.0.0.1:8000`). Log in with the API's
`ADMIN_TOKEN` (defaults to `change-me`).

## Flow

1. Edit categories/questions — each save hits the API immediately.
2. Click **Publish** on the Questions page once a batch of edits is ready.
   This bumps the API's pack version; mobile devices pick up all the
   changes together next time they sync.

## Build

```
npm run build
```
