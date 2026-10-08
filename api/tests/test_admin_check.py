from .conftest import ADMIN_HEADERS


def test_admin_check_rejects_missing_token(client):
    resp = client.get("/admin/check")
    assert resp.status_code == 401


def test_admin_check_accepts_valid_token_without_side_effects(client):
    resp = client.get("/admin/check", headers=ADMIN_HEADERS)
    assert resp.status_code == 200
    assert resp.json() == {"ok": True}

    # Confirms this endpoint never bumps the pack version.
    pack = client.get("/pack?since_version=0").json()
    assert pack["version"] == 1
