from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from .. import models, schemas
from ..auth import require_admin
from ..database import get_db

router = APIRouter(prefix="/categories", tags=["categories"])


@router.get("", response_model=list[schemas.CategoryOut])
def list_categories(language: str | None = None, db: Session = Depends(get_db)):
    query = db.query(models.Category)
    if language is not None:
        query = query.filter(models.Category.language == language)
    return query.order_by(models.Category.sort_order).all()


@router.post("", response_model=schemas.CategoryOut, dependencies=[Depends(require_admin)])
def create_category(payload: schemas.CategoryCreate, db: Session = Depends(get_db)):
    category = models.Category(**payload.model_dump())
    db.add(category)
    db.commit()
    db.refresh(category)
    return category


@router.put("/{category_id}", response_model=schemas.CategoryOut, dependencies=[Depends(require_admin)])
def update_category(category_id: int, payload: schemas.CategoryCreate, db: Session = Depends(get_db)):
    category = db.get(models.Category, category_id)
    if not category:
        raise HTTPException(status_code=404, detail="Category not found")
    for field, value in payload.model_dump().items():
        setattr(category, field, value)
    db.commit()
    db.refresh(category)
    return category


@router.delete("/{category_id}", status_code=204, dependencies=[Depends(require_admin)])
def delete_category(category_id: int, db: Session = Depends(get_db)):
    category = db.get(models.Category, category_id)
    if not category:
        raise HTTPException(status_code=404, detail="Category not found")
    db.delete(category)
    db.commit()
