import os

from sqlalchemy import create_engine, inspect, text
from sqlalchemy.orm import DeclarativeBase, sessionmaker

# SQLite by default so the API runs with zero setup; point DATABASE_URL at
# Postgres or any other SQLAlchemy-supported DB for real deployments without
# touching any other code.
DATABASE_URL = os.environ.get("DATABASE_URL", "sqlite:///./kid_smile.db")

connect_args = {"check_same_thread": False} if DATABASE_URL.startswith("sqlite") else {}
engine = create_engine(DATABASE_URL, connect_args=connect_args)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


class Base(DeclarativeBase):
    pass


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


# There's no migration tool (Alembic) at this project's scale — `create_all`
# only creates missing tables, it never alters existing ones. This adds any
# columns a model gained since the on-disk schema was created, so a database
# from before a field existed doesn't need to be dropped to pick it up.
def sync_missing_columns() -> None:
    inspector = inspect(engine)
    with engine.begin() as conn:
        for table in Base.metadata.tables.values():
            if not inspector.has_table(table.name):
                continue
            existing = {col["name"] for col in inspector.get_columns(table.name)}
            for column in table.columns:
                if column.name in existing:
                    continue
                col_type = column.type.compile(dialect=engine.dialect)
                conn.execute(text(f'ALTER TABLE "{table.name}" ADD COLUMN "{column.name}" {col_type}'))
