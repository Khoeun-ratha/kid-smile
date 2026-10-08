import os

from fastapi import Header, HTTPException

# A single shared admin token is enough at this scale (one small team
# managing quiz content) — no need for full user accounts/roles. Reads stay
# open (no token) so the mobile app can fetch packs without any auth setup.
ADMIN_TOKEN = os.environ.get("ADMIN_TOKEN", "change-me")


def require_admin(authorization: str = Header(default="")) -> None:
    expected = f"Bearer {ADMIN_TOKEN}"
    if authorization != expected:
        raise HTTPException(status_code=401, detail="Invalid or missing admin token")
