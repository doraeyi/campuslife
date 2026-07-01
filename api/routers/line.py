import random
import string
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

import models
import schemas
from auth import get_current_user
from database import get_db

router = APIRouter(prefix="/line", tags=["line"])


@router.get("/link", response_model=schemas.LineLinkRead)
def get_line_link(current_user: models.User = Depends(get_current_user)):
    return schemas.LineLinkRead(linked=current_user.line_user_id is not None)


@router.post("/link", response_model=schemas.LineLinkCodeRead)
def create_line_code(
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    code = "".join(random.choices(string.digits, k=6))
    current_user.line_link_code = code
    current_user.line_link_code_expires_at = datetime.now(timezone.utc) + timedelta(minutes=5)
    db.commit()
    return schemas.LineLinkCodeRead(code=code)


@router.delete("/link")
def unlink_line(
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    current_user.line_user_id = None
    db.commit()
    return {"status": "ok"}
