from fastapi import APIRouter, Depends, HTTPException, Response
from sqlalchemy.orm import Session

import models
import schemas
from auth import get_current_user
from database import get_db
from routers.line import push_message

router = APIRouter(prefix="/bank-notify", tags=["bank-notify"])


@router.get("/pending", response_model=list[schemas.PendingScreenshotRead])
def list_pending_screenshots(
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return (
        db.query(models.PendingBankScreenshot)
        .filter(models.PendingBankScreenshot.user_id == current_user.id)
        .order_by(models.PendingBankScreenshot.created_at.desc())
        .all()
    )


@router.get("/pending/{screenshot_id}/image")
def get_pending_screenshot_image(
    screenshot_id: int,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    shot = (
        db.query(models.PendingBankScreenshot)
        .filter(
            models.PendingBankScreenshot.id == screenshot_id,
            models.PendingBankScreenshot.user_id == current_user.id,
        )
        .first()
    )
    if shot is None:
        raise HTTPException(status_code=404, detail="找不到這張截圖")
    return Response(content=bytes(shot.image_data), media_type=shot.content_type)


@router.post("/pending/{screenshot_id}/notify")
def notify_pending_screenshot(
    screenshot_id: int,
    payload: schemas.NotifyPendingRequest,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """App 已經在手機端跑完 OCR、建立好交易了，這裡負責把結果推播回 LINE
    聊天室（用 push 而非 reply，因為原本收圖那個 webhook 的 reply token
    早就過期了），然後把這筆待確認截圖刪掉。"""
    shot = (
        db.query(models.PendingBankScreenshot)
        .filter(
            models.PendingBankScreenshot.id == screenshot_id,
            models.PendingBankScreenshot.user_id == current_user.id,
        )
        .first()
    )
    if shot is None:
        raise HTTPException(status_code=404, detail="找不到這張截圖")

    if current_user.line_user_id:
        push_message(current_user.line_user_id, payload.summary)

    db.delete(shot)
    db.commit()
    return {"status": "ok"}


@router.delete("/pending/{screenshot_id}")
def delete_pending_screenshot(
    screenshot_id: int,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    shot = (
        db.query(models.PendingBankScreenshot)
        .filter(
            models.PendingBankScreenshot.id == screenshot_id,
            models.PendingBankScreenshot.user_id == current_user.id,
        )
        .first()
    )
    if shot is None:
        raise HTTPException(status_code=404, detail="找不到這張截圖")
    db.delete(shot)
    db.commit()
    return {"status": "ok"}
