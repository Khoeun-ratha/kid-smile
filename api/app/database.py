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


# Rows inserted with explicit ids (seed, /admin/import) don't advance
# Postgres's id sequences, so the next auto-assigned id would collide. Call
# this after such inserts; it's a no-op on SQLite, which uses MAX(id) + 1.
def sync_id_sequences() -> None:
    if engine.dialect.name != "postgresql":
        return
    with engine.begin() as conn:
        for table in Base.metadata.tables.values():
            if "id" not in table.columns:
                continue
            seq = conn.execute(text(f"SELECT pg_get_serial_sequence('{table.name}', 'id')")).scalar()
            if seq is None:
                continue
            conn.execute(
                text(f'SELECT setval(:seq, COALESCE(MAX(id), 1), MAX(id) IS NOT NULL) FROM "{table.name}"'),
                {"seq": seq},
            )
