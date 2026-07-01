from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

import models
import schemas
from auth import get_current_user
from database import get_db

router = APIRouter(prefix="/cards", tags=["cards"])


@router.get("", response_model=list[schemas.CardRead])
def list_cards(
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return db.query(models.Card).filter(models.Card.user_id == current_user.id).all()


@router.post("", response_model=schemas.CardRead)
def create_card(
    payload: schemas.CardCreate,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    card = models.Card(user_id=current_user.id, **payload.model_dump())
    db.add(card)
    db.commit()
    db.refresh(card)
    return card


@router.patch("/{card_id}/balance", response_model=schemas.CardRead)
def update_card_balance(
    card_id: int,
    payload: schemas.CardBalanceUpdate,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    card = (
        db.query(models.Card)
        .filter(models.Card.id == card_id, models.Card.user_id == current_user.id)
        .first()
    )
    if card is None:
        raise HTTPException(status_code=404, detail="找不到這張卡片")
    card.balance = payload.balance
    db.commit()
    db.refresh(card)
    return card


@router.delete("/{card_id}")
def delete_card(
    card_id: int,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    card = (
        db.query(models.Card)
        .filter(models.Card.id == card_id, models.Card.user_id == current_user.id)
        .first()
    )
    if card is None:
        raise HTTPException(status_code=404, detail="找不到這張卡片")
    db.delete(card)
    db.commit()
    return {"status": "ok"}
