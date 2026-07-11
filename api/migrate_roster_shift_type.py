"""One-off migration: add roster_shifts.shift_type column, derived at
confirm-time by matching a cell's start/end time against the imported
job's ShiftPreset list (see routers/roster.py).

Usage: python migrate_roster_shift_type.py
"""

from sqlalchemy import inspect, text

from database import engine

with engine.begin() as conn:
    existing_columns = {col["name"] for col in inspect(conn).get_columns("roster_shifts")}

    if "shift_type" not in existing_columns:
        conn.execute(text("ALTER TABLE roster_shifts ADD COLUMN shift_type VARCHAR(20) NULL"))
        print("added roster_shifts.shift_type")

print("done")
