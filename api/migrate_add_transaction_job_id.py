"""One-off migration: add job_id column to the existing `transactions` table.
`Base.metadata.create_all()` in main.py only creates missing tables, not missing
columns on existing ones, so this needs to be run once against the live
database before deploying the new code.

Usage: python migrate_add_transaction_job_id.py
"""

from sqlalchemy import inspect, text

from database import engine

with engine.begin() as conn:
    existing_columns = {col["name"] for col in inspect(conn).get_columns("transactions")}

    if "job_id" not in existing_columns:
        conn.execute(text(
            "ALTER TABLE transactions ADD COLUMN job_id INT NULL"
        ))
        conn.execute(text(
            "CREATE INDEX ix_transactions_job_id ON transactions (job_id)"
        ))
        conn.execute(text(
            "ALTER TABLE transactions ADD CONSTRAINT fk_transactions_job_id "
            "FOREIGN KEY (job_id) REFERENCES jobs (id)"
        ))
        print("added transactions.job_id (+ index + FK)")

print("done")
