from .conftest import ADMIN_HEADERS


def test_create_and_list_category(client):
    resp = client.post(
        "/categories",
        json={"name": "Animals", "icon": "🐶", "color": "#FF0000", "sort_order": 1},
        headers=ADMIN_HEADERS,
    )
    assert resp.status_code == 200
    category_id = resp.json()["id"]

    resp = client.get("/categories")
    assert resp.status_code == 200
    assert len(resp.json()) == 1
    assert resp.json()[0]["id"] == category_id


def test_create_category_requires_admin_token(client):
    resp = client.post(
        "/categories",
        json={"name": "Animals", "icon": "🐶", "color": "#FF0000", "sort_order": 1},
    )
    assert resp.status_code == 401


def test_list_categories_filters_by_language(client):
    client.post(
        "/categories",
        json={"name": "Animals", "language": "en", "icon": "🐶", "color": "#FF0000", "sort_order": 1},
        headers=ADMIN_HEADERS,
    )
    client.post(
        "/categories",
        json={"name": "សត្វ", "language": "km", "icon": "🐶", "color": "#FF0000", "sort_order": 1},
        headers=ADMIN_HEADERS,
    )

    assert len(client.get("/categories").json()) == 2

    en_only = client.get("/categories?language=en").json()
    assert [c["name"] for c in en_only] == ["Animals"]

    km_only = client.get("/categories?language=km").json()
    assert [c["name"] for c in km_only] == ["សត្វ"]


def test_update_and_delete_category(client):
    created = client.post(
        "/categories",
        json={"name": "Colors", "icon": "🎨", "color": "#00FF00", "sort_order": 2},
        headers=ADMIN_HEADERS,
    ).json()

    updated = client.put(
        f"/categories/{created['id']}",
        json={"name": "Colours", "icon": "🎨", "color": "#00FF00", "sort_order": 2},
        headers=ADMIN_HEADERS,
    )
    assert updated.status_code == 200
    assert updated.json()["name"] == "Colours"

    deleted = client.delete(f"/categories/{created['id']}", headers=ADMIN_HEADERS)
    assert deleted.status_code == 204
    assert client.get("/categories").json() == []
