"""One-off migration: replace roster_uploads.store_name (free text) with a
job_id FK into jobs, so a roster import is tied to an existing Job instead
of a typed-in store name.

Usage: python migrate_roster_upload_job_link.py
"""

from sqlalchemy import inspect, text

from database import engine

with engine.begin() as conn:
    existing_columns = {col["name"] for col in inspect(conn).get_columns("roster_uploads")}

    if "store_name" in existing_columns:
        conn.execute(text("ALTER TABLE roster_uploads DROP COLUMN store_name"))
        print("dropped roster_uploads.store_name")

    if "job_id" not in existing_columns:
        conn.execute(text(
            "ALTER TABLE roster_uploads ADD COLUMN job_id INT NULL, "
            "ADD INDEX ix_roster_uploads_job_id (job_id), "
            "ADD CONSTRAINT fk_roster_uploads_job FOREIGN KEY (job_id) REFERENCES jobs(id)"
        ))
        print("added roster_uploads.job_id")

print("done")
