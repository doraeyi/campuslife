"""One-off migration: add credit_limit column to the existing `cards` table.
`Base.metadata.create_all()` in main.py only creates missing tables, not missing
columns on existing ones, so this needs to be run once against the live
database before deploying the new code.

Usage: python migrate_add_card_credit_limit.py
"""

from sqlalchemy import inspect, text

from database import engine

with engine.begin() as conn:
    existing_columns = {col["name"] for col in inspect(conn).get_columns("cards")}

    if "credit_limit" not in existing_columns:
        conn.execute(text(
            "ALTER TABLE cards ADD COLUMN credit_limit FLOAT NULL"
        ))
        print("added cards.credit_limit")

print("done")
