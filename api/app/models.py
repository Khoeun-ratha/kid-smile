from sqlalchemy import JSON, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .database import Base


class Meta(Base):
    """Single-row table holding the current published pack_version. Bumped
    every time an admin publishes edits, so mobile clients can cheaply ask
    "is there anything new" with one small request."""

    __tablename__ = "meta"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, default=1)
    pack_version: Mapped[int] = mapped_column(Integer, default=1)


class Category(Base):
    __tablename__ = "categories"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    name: Mapped[str] = mapped_column(String, nullable=False)
    # Which independent content set this belongs to ("en" or "km") — English
    # and Khmer are separate, unpaired collections of categories/questions,
    # not a translation of each other. Mobile only ever queries one language
    # at a time; there's no cross-language fallback.
    language: Mapped[str] = mapped_column(String, nullable=False, default="en")
    icon: Mapped[str] = mapped_column(String, nullable=False)
    color: Mapped[str] = mapped_column(String, nullable=False)
    sort_order: Mapped[int] = mapped_column(Integer, default=0)

    questions: Mapped[list["Question"]] = relationship(back_populates="category", cascade="all, delete-orphan")


class Question(Base):
    __tablename__ = "questions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    category_id: Mapped[int] = mapped_column(ForeignKey("categories.id"), nullable=False)
    prompt: Mapped[str] = mapped_column(String, nullable=False)
    choices: Mapped[list[str]] = mapped_column(JSON, nullable=False)
    # Matches the owning category's language — kept on the question too so a
    # single query can filter "give me every km question" without a join.
    language: Mapped[str] = mapped_column(String, nullable=False, default="en")
    correct_index: Mapped[int] = mapped_column(Integer, nullable=False)
    difficulty: Mapped[str] = mapped_column(String, default="easy")
    age_group: Mapped[str] = mapped_column(String, default="4-6")

    category: Mapped[Category] = relationship(back_populates="questions")
