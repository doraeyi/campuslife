"""One-off migration: add bank_name column to the existing `payments` table.
`Base.metadata.create_all()` in main.py only creates missing tables, not missing
columns on existing ones, so this needs to be run once against the live
database before deploying the new code.

Usage: python migrate_add_payment_bank_name.py
"""

from sqlalchemy import inspect, text

from database import engine

with engine.begin() as conn:
    existing_columns = {col["name"] for col in inspect(conn).get_columns("payments")}

    if "bank_name" not in existing_columns:
        conn.execute(text(
            "ALTER TABLE payments ADD COLUMN bank_name VARCHAR(100) NULL"
        ))
        conn.execute(text(
            "CREATE INDEX ix_payments_bank_name ON payments (bank_name)"
        ))
        print("added payments.bank_name (+ index)")

print("done")
