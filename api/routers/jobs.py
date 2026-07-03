from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import or_
from sqlalchemy.orm import Session

import models
import schemas
from auth import get_current_user
from database import get_db

router = APIRouter(prefix="/jobs", tags=["jobs"])


@router.get("", response_model=list[schemas.JobRead])
def list_jobs(
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return db.query(models.Job).filter(models.Job.user_id == current_user.id).all()


@router.post("", response_model=schemas.JobRead)
def create_job(
    payload: schemas.JobCreate,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    job = models.Job(user_id=current_user.id, **payload.model_dump())
    db.add(job)
    db.commit()
    db.refresh(job)
    return job


@router.put("/{job_id}", response_model=schemas.JobRead)
def update_job(
    job_id: int,
    payload: schemas.JobUpdate,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    job = (
        db.query(models.Job)
        .filter(models.Job.id == job_id, models.Job.user_id == current_user.id)
        .first()
    )
    if job is None:
        raise HTTPException(status_code=404, detail="找不到這個工作")
    for field, value in payload.model_dump().items():
        setattr(job, field, value)
    db.commit()
    db.refresh(job)
    return job


@router.delete("/{job_id}")
def delete_job(
    job_id: int,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    job = (
        db.query(models.Job)
        .filter(models.Job.id == job_id, models.Job.user_id == current_user.id)
        .first()
    )
    if job is None:
        raise HTTPException(status_code=404, detail="找不到這個工作")
    db.delete(job)
    db.commit()
    return {"status": "ok"}


# ── Shift presets ────────────────────────────────────────────────────────────

@router.post("/{job_id}/presets", response_model=schemas.ShiftPresetRead)
def add_preset(
    job_id: int,
    payload: schemas.ShiftPresetCreate,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    job = db.query(models.Job).filter(
        models.Job.id == job_id, models.Job.user_id == current_user.id
    ).first()
    if job is None:
        raise HTTPException(status_code=404, detail="找不到這個工作")
    preset = models.ShiftPreset(job_id=job_id, **payload.model_dump())
    db.add(preset)
    db.commit()
    db.refresh(preset)
    return preset


@router.delete("/{job_id}/presets/{preset_id}")
def delete_preset(
    job_id: int,
    preset_id: int,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    preset = (
        db.query(models.ShiftPreset)
        .join(models.Job)
        .filter(
            models.ShiftPreset.id == preset_id,
            models.ShiftPreset.job_id == job_id,
            models.Job.user_id == current_user.id,
        )
        .first()
    )
    if preset is None:
        raise HTTPException(status_code=404)
    db.delete(preset)
    db.commit()
    return {"status": "ok"}


# ── Job sharing ───────────────────────────────────────────────────────────────

@router.get("/{job_id}/shares", response_model=list[schemas.JobShareRead])
def list_job_shares(
    job_id: int,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    job = db.query(models.Job).filter(
        models.Job.id == job_id, models.Job.user_id == current_user.id
    ).first()
    if job is None:
        raise HTTPException(status_code=404, detail="找不到這個工作")
    return db.query(models.JobShare).filter(models.JobShare.job_id == job_id).all()


@router.post("/{job_id}/shares/{friend_id}", response_model=schemas.JobShareRead)
def add_job_share(
    job_id: int,
    friend_id: int,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    job = db.query(models.Job).filter(
        models.Job.id == job_id, models.Job.user_id == current_user.id
    ).first()
    if job is None:
        raise HTTPException(status_code=404, detail="找不到這個工作")

    friendship = db.query(models.Friendship).filter(
        models.Friendship.status == "accepted",
        or_(
            (models.Friendship.user_id == current_user.id) & (models.Friendship.friend_id == friend_id),
            (models.Friendship.user_id == friend_id) & (models.Friendship.friend_id == current_user.id),
        ),
    ).first()
    if friendship is None:
        raise HTTPException(status_code=400, detail="尚未成為好友")

    existing = db.query(models.JobShare).filter(
        models.JobShare.job_id == job_id,
        models.JobShare.shared_with_id == friend_id,
    ).first()
    if existing:
        return existing

    share = models.JobShare(job_id=job_id, owner_id=current_user.id, shared_with_id=friend_id)
    db.add(share)
    db.commit()
    db.refresh(share)
    return share


@router.delete("/{job_id}/shares/{friend_id}")
def remove_job_share(
    job_id: int,
    friend_id: int,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    share = db.query(models.JobShare).filter(
        models.JobShare.job_id == job_id,
        models.JobShare.owner_id == current_user.id,
        models.JobShare.shared_with_id == friend_id,
    ).first()
    if share is None:
        raise HTTPException(status_code=404)
    db.delete(share)
    db.commit()
    return {"status": "ok"}
