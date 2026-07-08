"""One-off migration:
- add cards.credit_group_key (decides which credit cards get merged into
  one home-page ring vs shown separately)
- add bank_credit_settings.manual_period_amount / manual_period_set_date
  (optional manual override for "how much have I spent this period",
  for users who don't want to log every transaction)

`Base.metadata.create_all()` in main.py only creates missing tables, not
missing columns on existing ones, so this needs to be run once against the
live database before deploying the new code.

Usage: python migrate_add_credit_group_key.py
"""

from sqlalchemy import inspect, text

from database import engine

with engine.begin() as conn:
    card_columns = {col["name"] for col in inspect(conn).get_columns("cards")}
    if "credit_group_key" not in card_columns:
        conn.execute(text("ALTER TABLE cards ADD COLUMN credit_group_key VARCHAR(120) NULL"))
        conn.execute(text("CREATE INDEX ix_cards_credit_group_key ON cards (credit_group_key)"))
        print("added cards.credit_group_key (+ index)")

    setting_columns = {col["name"] for col in inspect(conn).get_columns("bank_credit_settings")}
    if "manual_period_amount" not in setting_columns:
        conn.execute(text("ALTER TABLE bank_credit_settings ADD COLUMN manual_period_amount FLOAT NULL"))
        print("added bank_credit_settings.manual_period_amount")
    if "manual_period_set_date" not in setting_columns:
        conn.execute(text("ALTER TABLE bank_credit_settings ADD COLUMN manual_period_set_date DATE NULL"))
        print("added bank_credit_settings.manual_period_set_date")

print("done")
