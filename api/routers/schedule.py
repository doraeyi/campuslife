from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import or_
from sqlalchemy.orm import Session

import models
import schemas
from auth import get_current_user
from database import get_db

router = APIRouter(prefix="/schedule", tags=["schedule"])


def _are_friends(db: Session, user_id: int, other_id: int) -> bool:
    friendship = (
        db.query(models.Friendship)
        .filter(
            models.Friendship.status == "accepted",
            or_(
                (models.Friendship.user_id == user_id) & (models.Friendship.friend_id == other_id),
                (models.Friendship.user_id == other_id) & (models.Friendship.friend_id == user_id),
            ),
        )
        .first()
    )
    return friendship is not None


@router.get("", response_model=list[schemas.ShiftRead])
def list_shifts(
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return (
        db.query(models.Shift)
        .filter(models.Shift.user_id == current_user.id)
        .order_by(models.Shift.date)
        .all()
    )


@router.get("/friend/{friend_id}", response_model=list[schemas.ShiftRead])
def list_friend_shifts(
    friend_id: int,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if not _are_friends(db, current_user.id, friend_id):
        raise HTTPException(status_code=403, detail="不是好友,無法查看班表")

    return (
        db.query(models.Shift)
        .filter(models.Shift.user_id == friend_id)
        .order_by(models.Shift.date)
        .all()
    )


@router.post("", response_model=schemas.ShiftRead)
def create_shift(
    shift: schemas.ShiftCreate,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if shift.job_id is not None:
        job = (
            db.query(models.Job)
            .filter(models.Job.id == shift.job_id, models.Job.user_id == current_user.id)
            .first()
        )
        if job is None:
            raise HTTPException(status_code=404, detail="找不到這個工作")

    db_shift = models.Shift(**shift.model_dump(), user_id=current_user.id)
    db.add(db_shift)
    db.commit()
    db.refresh(db_shift)
    return db_shift


@router.delete("/{shift_id}")
def delete_shift(
    shift_id: int,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    shift = (
        db.query(models.Shift)
        .filter(models.Shift.id == shift_id, models.Shift.user_id == current_user.id)
        .first()
    )
    if shift is None:
        raise HTTPException(status_code=404, detail="找不到這筆班表")
    db.delete(shift)
    db.commit()
    return {"status": "ok"}
