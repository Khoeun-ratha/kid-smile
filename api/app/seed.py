"""Populates a fresh database with the same starter content the mobile app
ships offline, so the API is demoable immediately: `python -m app.seed`."""

import json
from pathlib import Path

from .database import Base, SessionLocal, engine, sync_id_sequences, sync_missing_columns
from .models import Category, Meta, Question

SEED_PATH = Path(__file__).resolve().parent.parent.parent / "mobile" / "assets" / "seed_pack.json"


def seed() -> None:
    Base.metadata.create_all(bind=engine)
    sync_missing_columns()
    db = SessionLocal()
    try:
        if db.query(Category).count() > 0:
            print("Database already has content, skipping seed.")
            return

        data = json.loads(SEED_PATH.read_text(encoding="utf-8"))

        for c in data["categories"]:
            db.add(
                Category(
                    id=c["id"],
                    name=c["name"],
                    language="en",
                    icon=c["icon"],
                    color=c["color"],
                    sort_order=c["sort_order"],
                )
            )
        for q in data["questions"]:
            db.add(
                Question(
                    id=q["id"],
                    category_id=q["category_id"],
                    prompt=q["prompt"],
                    choices=q["choices"],
                    language="en",
                    correct_index=q["correct_index"],
                    difficulty=q["difficulty"],
                    age_group=q["age_group"],
                )
            )
        db.add(Meta(id=1, pack_version=data["version"]))
        db.commit()
        sync_id_sequences()
        print(f"Seeded {len(data['categories'])} categories and {len(data['questions'])} questions.")
    finally:
        db.close()


if __name__ == "__main__":
    seed()
