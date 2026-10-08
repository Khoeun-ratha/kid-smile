from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from .. import models, schemas
from ..auth import require_admin
from ..database import get_db

router = APIRouter(prefix="/questions", tags=["questions"])


@router.get("", response_model=list[schemas.QuestionOut])
def list_questions(category_id: int | None = None, language: str | None = None, db: Session = Depends(get_db)):
    query = db.query(models.Question)
    if category_id is not None:
        query = query.filter(models.Question.category_id == category_id)
    if language is not None:
        query = query.filter(models.Question.language == language)
    return query.all()


@router.post("", response_model=schemas.QuestionOut, dependencies=[Depends(require_admin)])
def create_question(payload: schemas.QuestionCreate, db: Session = Depends(get_db)):
    question = models.Question(**payload.model_dump())
    db.add(question)
    db.commit()
    db.refresh(question)
    return question


@router.put("/{question_id}", response_model=schemas.QuestionOut, dependencies=[Depends(require_admin)])
def update_question(question_id: int, payload: schemas.QuestionCreate, db: Session = Depends(get_db)):
    question = db.get(models.Question, question_id)
    if not question:
        raise HTTPException(status_code=404, detail="Question not found")
    for field, value in payload.model_dump().items():
        setattr(question, field, value)
    db.commit()
    db.refresh(question)
    return question


@router.delete("/{question_id}", status_code=204, dependencies=[Depends(require_admin)])
def delete_question(question_id: int, db: Session = Depends(get_db)):
    question = db.get(models.Question, question_id)
    if not question:
        raise HTTPException(status_code=404, detail="Question not found")
    db.delete(question)
    db.commit()
