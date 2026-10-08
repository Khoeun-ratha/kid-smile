from .conftest import ADMIN_HEADERS


def _seed_via_api(client):
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
    return category


def test_import_replaces_existing_content_and_keeps_given_ids(client):
    _seed_via_api(client)

    payload = {
        "categories": [
            {"id": 5, "name": "Colors", "icon": "🎨", "color": "#00FF00", "sort_order": 1},
        ],
        "questions": [
            {
                "id": 99,
                "category_id": 5,
                "prompt": "What color is the sky?",
                "choices": ["Blue", "Red", "Green", "Yellow"],
                "correct_index": 0,
            },
        ],
    }
    resp = client.post("/admin/import", json=payload, headers=ADMIN_HEADERS)
    assert resp.status_code == 200
    assert resp.json() == {"categories": 1, "questions": 1}

    categories = client.get("/categories").json()
    assert len(categories) == 1
    assert categories[0] == {
        "id": 5,
        "name": "Colors",
        "language": "en",
        "icon": "🎨",
        "color": "#00FF00",
        "sort_order": 1,
    }

    questions = client.get("/questions").json()
    assert len(questions) == 1
    assert questions[0]["category_id"] == 5
    assert questions[0]["prompt"] == "What color is the sky?"


def test_import_rejects_question_referencing_unknown_category(client):
    payload = {
        "categories": [{"id": 1, "name": "Colors", "icon": "🎨", "color": "#00FF00", "sort_order": 1}],
        "questions": [
            {
                "category_id": 2,
                "prompt": "Orphan question",
                "choices": ["A", "B", "C", "D"],
                "correct_index": 0,
            }
        ],
    }
    resp = client.post("/admin/import", json=payload, headers=ADMIN_HEADERS)
    assert resp.status_code == 400

    # Nothing should have been written on a rejected import.
    assert client.get("/categories").json() == []


def test_import_requires_admin(client):
    resp = client.post("/admin/import", json={"categories": [], "questions": []})
    assert resp.status_code == 401


def test_reset_wipes_categories_and_questions(client):
    _seed_via_api(client)

    resp = client.post("/admin/reset", headers=ADMIN_HEADERS)
    assert resp.status_code == 200
    assert resp.json() == {"ok": True}

    assert client.get("/categories").json() == []
    assert client.get("/questions").json() == []


def test_reset_requires_admin(client):
    resp = client.post("/admin/reset")
    assert resp.status_code == 401
