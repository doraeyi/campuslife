from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

import models
import schemas
from auth import get_current_user
from database import get_db

router = APIRouter(prefix="/transactions", tags=["transactions"])


@router.get("", response_model=list[schemas.TransactionRead])
def list_transactions(
    card_id: int | None = Query(None),
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    q = db.query(models.Transaction).filter(models.Transaction.user_id == current_user.id)
    if card_id is not None:
        q = q.filter(models.Transaction.card_id == card_id)
    return q.order_by(models.Transaction.created_at.desc()).all()


@router.post("", response_model=schemas.TransactionRead)
def create_transaction(
    payload: schemas.TransactionCreate,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if payload.card_id is not None:
        card = (
            db.query(models.Card)
            .filter(models.Card.id == payload.card_id, models.Card.user_id == current_user.id)
            .first()
        )
        if card is None:
            raise HTTPException(status_code=404, detail="找不到這張卡片")
        if card.balance is not None:
            card.balance += payload.amount

    data = payload.model_dump(exclude={"date"})
    tx = models.Transaction(user_id=current_user.id, **data)
    db.add(tx)
    db.commit()
    db.refresh(tx)
    return tx


@router.delete("/{transaction_id}")
def delete_transaction(
    transaction_id: int,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    tx = (
        db.query(models.Transaction)
        .filter(models.Transaction.id == transaction_id, models.Transaction.user_id == current_user.id)
        .first()
    )
    if tx is None:
        raise HTTPException(status_code=404, detail="找不到這筆交易")

    if tx.card_id is not None:
        card = db.query(models.Card).filter(models.Card.id == tx.card_id).first()
        if card is not None and card.balance is not None:
            card.balance -= tx.amount

    db.delete(tx)
    db.commit()
    return {"status": "ok"}
