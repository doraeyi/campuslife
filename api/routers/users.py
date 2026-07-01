import random
import string
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

import models
import schemas
from auth import get_current_user, hash_password, verify_password
from database import get_db

router = APIRouter(prefix="/users", tags=["users"])


@router.get("/me", response_model=schemas.UserProfileRead)
def get_me(current_user: models.User = Depends(get_current_user)):
    return schemas.UserProfileRead(
        id=current_user.id,
        email=current_user.email,
        name=current_user.display_name,
        picture=current_user.picture,
    )


@router.patch("/me", response_model=schemas.UserProfileRead)
def update_me(
    payload: schemas.UpdateProfilePayload,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if payload.name is not None:
        current_user.display_name = payload.name
    if payload.picture is not None:
        current_user.picture = payload.picture
    db.commit()
    db.refresh(current_user)
    return schemas.UserProfileRead(
        id=current_user.id,
        email=current_user.email,
        name=current_user.display_name,
        picture=current_user.picture,
    )


@router.get("/me/google", response_model=schemas.GoogleLinkRead)
def get_google_link(current_user: models.User = Depends(get_current_user)):
    return schemas.GoogleLinkRead(linked=current_user.google_id is not None)


@router.delete("/me/google")
def unlink_google(
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    current_user.google_id = None
    db.commit()
    return {"status": "ok"}


@router.get("/me/has-password", response_model=schemas.HasPasswordRead)
def has_password(current_user: models.User = Depends(get_current_user)):
    return schemas.HasPasswordRead(has_password=bool(current_user.password_hash))


@router.patch("/me/password")
def update_password(
    payload: schemas.PasswordUpdate,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if not verify_password(payload.current_password, current_user.password_hash or ""):
        raise HTTPException(status_code=400, detail="目前密碼不正確")
    current_user.password_hash = hash_password(payload.new_password)
    db.commit()
    return {"status": "ok"}
