"""One-off migration:
- add payments.period_closing_date (which billing period a payment settles)
- drop bank_credit_settings.starting_balance / starting_balance_date
  (no longer used — bill amounts are computed directly from transactions
  within each period's date range, no manual baseline needed)

`Base.metadata.create_all()` in main.py only creates missing tables, not
missing/removed columns on existing ones, so this needs to be run once
against the live database before deploying the new code.

Usage: python migrate_simplify_bank_credit.py
"""

from sqlalchemy import inspect, text

from database import engine

with engine.begin() as conn:
    payment_columns = {col["name"] for col in inspect(conn).get_columns("payments")}
    if "period_closing_date" not in payment_columns:
        conn.execute(text(
            "ALTER TABLE payments ADD COLUMN period_closing_date DATE NULL"
        ))
        conn.execute(text(
            "CREATE INDEX ix_payments_period_closing_date ON payments (period_closing_date)"
        ))
        print("added payments.period_closing_date (+ index)")

    setting_columns = {col["name"] for col in inspect(conn).get_columns("bank_credit_settings")}
    if "starting_balance" in setting_columns:
        conn.execute(text("ALTER TABLE bank_credit_settings DROP COLUMN starting_balance"))
        print("dropped bank_credit_settings.starting_balance")
    if "starting_balance_date" in setting_columns:
        conn.execute(text("ALTER TABLE bank_credit_settings DROP COLUMN starting_balance_date"))
        print("dropped bank_credit_settings.starting_balance_date")

print("done")
