"""One-off migration: add reset_code/reset_code_expires_at columns to the
existing `users` table for the forgot-password flow.

Usage: python migrate_add_password_reset_fields.py
"""

from sqlalchemy import inspect, text

from database import engine

with engine.begin() as conn:
    existing_columns = {col["name"] for col in inspect(conn).get_columns("users")}

    if "reset_code" not in existing_columns:
        conn.execute(text("ALTER TABLE users ADD COLUMN reset_code VARCHAR(10) NULL"))
        print("added users.reset_code")

    if "reset_code_expires_at" not in existing_columns:
        conn.execute(text("ALTER TABLE users ADD COLUMN reset_code_expires_at DATETIME NULL"))
        print("added users.reset_code_expires_at")

print("done")
