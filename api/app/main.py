from fastapi import Depends, FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session

from . import models, schemas
from .auth import require_admin
from .database import Base, engine, get_db, sync_missing_columns
from .routers import categories, pack, questions

Base.metadata.create_all(bind=engine)
sync_missing_columns()

app = FastAPI(title="Kid Smile API")

# The Vue admin dashboard runs on a different origin during development.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(categories.router)
app.include_router(questions.router)
app.include_router(pack.router)


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/admin/check", dependencies=[Depends(require_admin)])
def admin_check():
    """Side-effect-free way for the admin dashboard to validate a token on
    login, without touching content or bumping the pack version."""
    return {"ok": True}


@app.post("/admin/import", dependencies=[Depends(require_admin)])
def import_data(payload: schemas.ImportPayload, db: Session = Depends(get_db)):
    """Replaces all categories and questions with the given set in one
    transaction — the bulk alternative to adding content one form at a time.
    Categories keep the ids given in the payload so questions in the same
    file can reference them, and so a previously exported pack re-imports
    without minting new ids."""
    category_ids = {c.id for c in payload.categories}
    for q in payload.questions:
        if q.category_id not in category_ids:
            raise HTTPException(
                status_code=400,
                detail=f"Question references category_id {q.category_id}, which isn't in this import's categories.",
            )

    db.query(models.Question).delete()
    db.query(models.Category).delete()
    for c in payload.categories:
        db.add(models.Category(**c.model_dump()))
    for q in payload.questions:
        data = q.model_dump()
        data.pop("id", None)
        db.add(models.Question(**data))
    db.commit()

    return {
        "categories": len(payload.categories),
        "questions": len(payload.questions),
    }


@app.post("/admin/reset", dependencies=[Depends(require_admin)])
def reset_data(db: Session = Depends(get_db)):
    """Wipes all categories and questions (deleting a category already
    cascades to its questions). Doesn't touch pack_version — publish
    afterward to push the now-empty pack to mobile devices."""
    db.query(models.Question).delete()
    db.query(models.Category).delete()
    db.commit()
    return {"ok": True}
