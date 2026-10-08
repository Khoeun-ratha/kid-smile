from fastapi import APIRouter, Depends, Response
from sqlalchemy.orm import Session

from .. import models, schemas
from ..auth import require_admin
from ..database import get_db

router = APIRouter(tags=["pack"])


def _get_or_create_meta(db: Session) -> models.Meta:
    meta = db.get(models.Meta, 1)
    if not meta:
        meta = models.Meta(id=1, pack_version=1)
        db.add(meta)
        db.commit()
        db.refresh(meta)
    return meta


@router.get("/pack", response_model=schemas.Pack | None)
def get_pack(response: Response, since_version: int = 0, language: str = "en", db: Session = Depends(get_db)):
    """Returns the current pack for `language` if it's newer than
    `since_version`, otherwise 204 (no update) so mobile clients can poll
    cheaply. `pack_version` is a single global counter shared across every
    language, so a change to one language's content causes devices on any
    language to refetch — occasionally redundant, but simple and cheap at
    this scale."""
    meta = _get_or_create_meta(db)
    if meta.pack_version <= since_version:
        response.status_code = 204
        return None

    categories = (
        db.query(models.Category)
        .filter(models.Category.language == language)
        .order_by(models.Category.sort_order)
        .all()
    )
    questions = db.query(models.Question).filter(models.Question.language == language).all()
    return schemas.Pack(version=meta.pack_version, categories=categories, questions=questions)


@router.post("/publish", dependencies=[Depends(require_admin)])
def publish(db: Session = Depends(get_db)):
    """Bumps the pack version so mobile devices know there's new content to
    pull down. Called by the admin dashboard once edits are ready to ship,
    rather than on every single CRUD call, so a batch of edits goes out
    together."""
    meta = _get_or_create_meta(db)
    meta.pack_version += 1
    db.commit()
    return {"pack_version": meta.pack_version}
