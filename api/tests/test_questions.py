from .conftest import ADMIN_HEADERS


def _make_category(client):
    return client.post(
        "/categories",
        json={"name": "Animals", "icon": "🐶", "color": "#FF0000", "sort_order": 1},
        headers=ADMIN_HEADERS,
    ).json()


def test_create_and_filter_questions_by_category(client):
    animals = _make_category(client)
    colors = client.post(
        "/categories",
        json={"name": "Colors", "icon": "🎨", "color": "#00FF00", "sort_order": 2},
        headers=ADMIN_HEADERS,
    ).json()

    client.post(
        "/questions",
        json={
            "category_id": animals["id"],
            "prompt": "Which animal says Moo?",
            "choices": ["Cow", "Cat", "Duck", "Horse"],
            "correct_index": 0,
        },
        headers=ADMIN_HEADERS,
    )
    client.post(
        "/questions",
        json={
            "category_id": colors["id"],
            "prompt": "What color is a banana?",
            "choices": ["Red", "Yellow", "Blue", "Black"],
            "correct_index": 1,
        },
        headers=ADMIN_HEADERS,
    )

    all_questions = client.get("/questions").json()
    assert len(all_questions) == 2

    animal_questions = client.get(f"/questions?category_id={animals['id']}").json()
    assert len(animal_questions) == 1
    assert animal_questions[0]["prompt"] == "Which animal says Moo?"


def test_delete_question_requires_admin(client):
    animals = _make_category(client)
    question = client.post(
        "/questions",
        json={
            "category_id": animals["id"],
            "prompt": "Which animal says Moo?",
            "choices": ["Cow", "Cat", "Duck", "Horse"],
            "correct_index": 0,
        },
        headers=ADMIN_HEADERS,
    ).json()

    resp = client.delete(f"/questions/{question['id']}")
    assert resp.status_code == 401

    resp = client.delete(f"/questions/{question['id']}", headers=ADMIN_HEADERS)
    assert resp.status_code == 204
