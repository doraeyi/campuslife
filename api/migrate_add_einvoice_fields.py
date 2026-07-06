"""One-off migration: add source/einvoice_number/einvoice_random_code columns to
the existing `transactions` table. `Base.metadata.create_all()` in main.py only
creates missing tables, not missing columns on existing ones, so this needs to
be run once against the live database before deploying the new code.

Usage: python migrate_add_einvoice_fields.py
"""

from sqlalchemy import inspect, text

from database import engine

with engine.begin() as conn:
    existing_columns = {col["name"] for col in inspect(conn).get_columns("transactions")}

    if "source" not in existing_columns:
        conn.execute(text(
            "ALTER TABLE transactions ADD COLUMN source VARCHAR(20) NOT NULL DEFAULT 'manual'"
        ))
        print("added transactions.source")

    if "einvoice_number" not in existing_columns:
        conn.execute(text(
            "ALTER TABLE transactions ADD COLUMN einvoice_number VARCHAR(10) NULL"
        ))
        conn.execute(text(
            "CREATE INDEX ix_transactions_einvoice_number ON transactions (einvoice_number)"
        ))
        conn.execute(text(
            "ALTER TABLE transactions ADD CONSTRAINT uq_transaction_user_einvoice "
            "UNIQUE (user_id, einvoice_number)"
        ))
        print("added transactions.einvoice_number (+ index + unique constraint)")

    if "einvoice_random_code" not in existing_columns:
        conn.execute(text(
            "ALTER TABLE transactions ADD COLUMN einvoice_random_code VARCHAR(4) NULL"
        ))
        print("added transactions.einvoice_random_code")

print("done")
