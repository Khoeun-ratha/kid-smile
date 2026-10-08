from pydantic import BaseModel, ConfigDict


class CategoryBase(BaseModel):
    name: str
    language: str = "en"
    icon: str
    color: str
    sort_order: int = 0


class CategoryCreate(CategoryBase):
    pass


class CategoryOut(CategoryBase):
    model_config = ConfigDict(from_attributes=True)
    id: int


class QuestionBase(BaseModel):
    category_id: int
    prompt: str
    choices: list[str]
    language: str = "en"
    correct_index: int
    difficulty: str = "easy"
    age_group: str = "4-6"


class QuestionCreate(QuestionBase):
    pass


class QuestionOut(QuestionBase):
    model_config = ConfigDict(from_attributes=True)
    id: int


class Pack(BaseModel):
    version: int
    categories: list[CategoryOut]
    questions: list[QuestionOut]


class CategoryImport(CategoryBase):
    # Carries the id so questions in the same import can reference it, and so
    # re-importing a previously exported file round-trips cleanly instead of
    # minting new ids every time.
    id: int


class QuestionImport(QuestionBase):
    id: int | None = None


class ImportPayload(BaseModel):
    categories: list[CategoryImport]
    questions: list[QuestionImport]
