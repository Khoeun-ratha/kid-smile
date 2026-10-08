from .conftest import ADMIN_HEADERS


def test_pack_is_empty_but_versioned_before_any_content_or_publish(client):
    resp = client.get("/pack?since_version=0")
    assert resp.status_code == 200
    body = resp.json()
    assert body["version"] == 1
    assert body["categories"] == []
    assert body["questions"] == []


def test_publish_bumps_version_and_pack_reflects_content(client):
    category = client.post(
        "/categories",
        json={"name": "Animals", "icon": "🐶", "color": "#FF0000", "sort_order": 1},
        headers=ADMIN_HEADERS,
    ).json()
    client.post(
        "/questions",
        json={
            "category_id": category["id"],
            "prompt": "Which animal says Moo?",
            "choices": ["Cow", "Cat", "Duck", "Horse"],
            "correct_index": 0,
        },
        headers=ADMIN_HEADERS,
    )

    published = client.post("/publish", headers=ADMIN_HEADERS)
    assert published.status_code == 200
    version = published.json()["pack_version"]

    pack = client.get(f"/pack?since_version={version - 1}")
    assert pack.status_code == 200
    body = pack.json()
    assert body["version"] == version
    assert len(body["categories"]) == 1
    assert len(body["questions"]) == 1


def test_pack_only_includes_the_requested_language(client):
    en_category = client.post(
        "/categories",
        json={"name": "Animals", "language": "en", "icon": "🐶", "color": "#FF0000", "sort_order": 1},
        headers=ADMIN_HEADERS,
    ).json()
    km_category = client.post(
        "/categories",
        json={"name": "សត្វ", "language": "km", "icon": "🐶", "color": "#FF0000", "sort_order": 1},
        headers=ADMIN_HEADERS,
    ).json()
    client.post(
        "/questions",
        json={
            "category_id": en_category["id"],
            "prompt": "Which animal says Moo?",
            "choices": ["Cow", "Cat", "Duck", "Horse"],
            "language": "en",
            "correct_index": 0,
        },
        headers=ADMIN_HEADERS,
    )
    client.post(
        "/questions",
        json={
            "category_id": km_category["id"],
            "prompt": "សត្វអ្វីដែលស្រែកថា \"អុំ\"?",
            "choices": ["គោ", "ឆ្មា", "ទា", "សេះ"],
            "language": "km",
            "correct_index": 0,
        },
        headers=ADMIN_HEADERS,
    )
    client.post("/publish", headers=ADMIN_HEADERS)

    en_pack = client.get("/pack?since_version=0&language=en").json()
    assert [c["name"] for c in en_pack["categories"]] == ["Animals"]
    assert len(en_pack["questions"]) == 1

    km_pack = client.get("/pack?since_version=0&language=km").json()
    assert [c["name"] for c in km_pack["categories"]] == ["សត្វ"]
    assert len(km_pack["questions"]) == 1

    # Default (no `language`) behaves as "en" for backward compatibility.
    default_pack = client.get("/pack?since_version=0").json()
    assert [c["name"] for c in default_pack["categories"]] == ["Animals"]


def test_pack_returns_204_when_client_already_up_to_date(client):
    published = client.post("/publish", headers=ADMIN_HEADERS).json()
    resp = client.get(f"/pack?since_version={published['pack_version']}")
    assert resp.status_code == 204


def test_publish_requires_admin(client):
    resp = client.post("/publish")
    assert resp.status_code == 401
