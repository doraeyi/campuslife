from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Response
from sqlalchemy.orm import Session

import models
import schemas
from auth import get_current_user
from database import get_db
from routers.line import push_message

router = APIRouter(prefix="/roster", tags=["roster"])


def _create_roster_upload(
    db: Session, current_user: models.User, payload: schemas.RosterConfirmRequest
) -> models.RosterUpload:
    upload = models.RosterUpload(
        user_id=current_user.id,
        job_id=payload.job_id,
        period_start=payload.period_start,
        period_end=payload.period_end,
    )
    db.add(upload)
    db.flush()  # 拿到 upload.id 供底下的 RosterShift 使用

    for entry in payload.shifts:
        db.add(models.RosterShift(
            user_id=current_user.id,
            roster_upload_id=upload.id,
            employee_name=entry.employee_name,
            date=entry.date,
            start_time=entry.start_time,
            end_time=entry.end_time,
            note=entry.note,
        ))
    return upload


# ── 直接匯入（從相簿手動選照片，本機 OCR 完就直接送校正結果，不經過待處理照片）──

@router.post("/confirm", response_model=schemas.RosterUploadRead)
def confirm_roster_import(
    payload: schemas.RosterConfirmRequest,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    upload = _create_roster_upload(db, current_user, payload)
    db.commit()
    db.refresh(upload)
    return upload


# ── 待處理的班表照片（LINE 傳來，等 App 端 OCR + 校正確認）──────────────────

@router.get("/pending", response_model=list[schemas.PendingRosterPhotoRead])
def list_pending_roster_photos(
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return (
        db.query(models.PendingRosterPhoto)
        .filter(models.PendingRosterPhoto.user_id == current_user.id)
        .order_by(models.PendingRosterPhoto.created_at.desc())
        .all()
    )


@router.get("/pending/{photo_id}/image")
def get_pending_roster_photo_image(
    photo_id: int,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    photo = (
        db.query(models.PendingRosterPhoto)
        .filter(
            models.PendingRosterPhoto.id == photo_id,
            models.PendingRosterPhoto.user_id == current_user.id,
        )
        .first()
    )
    if photo is None:
        raise HTTPException(status_code=404, detail="找不到這張照片")
    return Response(content=bytes(photo.image_data), media_type=photo.content_type)


@router.post("/pending/{photo_id}/confirm", response_model=schemas.RosterUploadRead)
def confirm_pending_roster_photo(
    photo_id: int,
    payload: schemas.RosterConfirmRequest,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """App 端已經跑完 OCR、經過使用者校正確認了，這裡負責把整批班表寫進資料庫，
    推播確認訊息回 LINE（用 push 而非 reply，原本收圖的 reply token 早就過期了），
    然後把這張待確認照片刪掉。"""
    photo = (
        db.query(models.PendingRosterPhoto)
        .filter(
            models.PendingRosterPhoto.id == photo_id,
            models.PendingRosterPhoto.user_id == current_user.id,
        )
        .first()
    )
    if photo is None:
        raise HTTPException(status_code=404, detail="找不到這張照片")

    upload = _create_roster_upload(db, current_user, payload)

    if current_user.line_user_id:
        push_message(current_user.line_user_id, f"✅ 班表已匯入！共 {len(payload.shifts)} 筆班次。")

    db.delete(photo)
    db.commit()
    db.refresh(upload)
    return upload


@router.delete("/pending/{photo_id}")
def delete_pending_roster_photo(
    photo_id: int,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    photo = (
        db.query(models.PendingRosterPhoto)
        .filter(
            models.PendingRosterPhoto.id == photo_id,
            models.PendingRosterPhoto.user_id == current_user.id,
        )
        .first()
    )
    if photo is None:
        raise HTTPException(status_code=404, detail="找不到這張照片")
    db.delete(photo)
    db.commit()
    return {"status": "ok"}


# ── 已匯入的班表批次 ─────────────────────────────────────────────────────────

@router.get("/uploads", response_model=list[schemas.RosterUploadRead])
def list_roster_uploads(
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return (
        db.query(models.RosterUpload)
        .filter(models.RosterUpload.user_id == current_user.id)
        .order_by(models.RosterUpload.period_start.desc())
        .all()
    )


@router.delete("/uploads/{upload_id}")
def delete_roster_upload(
    upload_id: int,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    upload = (
        db.query(models.RosterUpload)
        .filter(models.RosterUpload.id == upload_id, models.RosterUpload.user_id == current_user.id)
        .first()
    )
    if upload is None:
        raise HTTPException(status_code=404, detail="找不到這個匯入批次")
    db.delete(upload)  # cascade="all, delete-orphan" 一併刪掉底下的 RosterShift
    db.commit()
    return {"status": "ok"}


# ── 團隊班表檢視 ─────────────────────────────────────────────────────────────

@router.get("/shifts", response_model=list[schemas.RosterShiftRead])
def list_roster_shifts(
    start: date,
    end: date,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return (
        db.query(models.RosterShift)
        .filter(
            models.RosterShift.user_id == current_user.id,
            models.RosterShift.date >= start,
            models.RosterShift.date <= end,
        )
        .order_by(models.RosterShift.date, models.RosterShift.employee_name)
        .all()
    )
