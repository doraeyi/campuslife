"""One-off migration: add credit_account_id column to the existing `cards` table.
`Base.metadata.create_all()` in main.py only creates missing tables, not missing
columns on existing ones, so this needs to be run once against the live
database before deploying the new code.

IMPORTANT: run this AFTER the backend has started at least once with the new
models loaded, so the `credit_accounts` table already exists (this column is
a foreign key into it).

Usage: python migrate_add_card_credit_account.py
"""

from sqlalchemy import inspect, text

from database import engine

with engine.begin() as conn:
    existing_columns = {col["name"] for col in inspect(conn).get_columns("cards")}

    if "credit_account_id" not in existing_columns:
        conn.execute(text(
            "ALTER TABLE cards ADD COLUMN credit_account_id INT NULL"
        ))
        conn.execute(text(
            "CREATE INDEX ix_cards_credit_account_id ON cards (credit_account_id)"
        ))
        conn.execute(text(
            "ALTER TABLE cards ADD CONSTRAINT fk_cards_credit_account_id "
            "FOREIGN KEY (credit_account_id) REFERENCES credit_accounts (id)"
        ))
        print("added cards.credit_account_id (+ index + FK)")

print("done")
