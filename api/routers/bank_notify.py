from fastapi import APIRouter, Depends, HTTPException, Response
from sqlalchemy.orm import Session

import models
import schemas
from auth import get_current_user
from database import get_db

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
