"""One-off migration: add roster_import_expected_until column to the
existing `users` table for the LINE roster-photo import flow.

Usage: python migrate_add_roster_import_flag.py
"""

from sqlalchemy import inspect, text

from database import engine

with engine.begin() as conn:
    existing_columns = {col["name"] for col in inspect(conn).get_columns("users")}

    if "roster_import_expected_until" not in existing_columns:
        conn.execute(text("ALTER TABLE users ADD COLUMN roster_import_expected_until DATETIME NULL"))
        print("added users.roster_import_expected_until")

print("done")
