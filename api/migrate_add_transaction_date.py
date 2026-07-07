"""One-off migration: add transaction_date column to the existing `transactions` table.
`Base.metadata.create_all()` in main.py only creates missing tables, not missing
columns on existing ones, so this needs to be run once against the live
database before deploying the new code.

Usage: python migrate_add_transaction_date.py
"""

from sqlalchemy import inspect, text

from database import engine

with engine.begin() as conn:
    existing_columns = {col["name"] for col in inspect(conn).get_columns("transactions")}

    if "transaction_date" not in existing_columns:
        conn.execute(text(
            "ALTER TABLE transactions ADD COLUMN transaction_date DATE NULL"
        ))
        print("added transactions.transaction_date")

print("done")
