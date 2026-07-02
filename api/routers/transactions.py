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
    tx_type = payload.transaction_type or "expense"
    amount = payload.amount
    if tx_type == "expense" and amount > 0:
        amount = -amount
    elif tx_type == "income" and amount < 0:
        amount = -amount

    if payload.card_id is not None:
        card = (
            db.query(models.Card)
            .filter(models.Card.id == payload.card_id, models.Card.user_id == current_user.id)
            .first()
        )
        if card is None:
            raise HTTPException(status_code=404, detail="找不到這張卡片")
        if card.balance is not None:
            card.balance += amount

    data = payload.model_dump(exclude={"date", "type", "category_id"})
    data["amount"] = amount
    data["transaction_type"] = tx_type
    if not data.get("description"):
        data["description"] = data.get("note") or ""
    tx = models.Transaction(user_id=current_user.id, **data)
    db.add(tx)
    db.commit()
    db.refresh(tx)
    return tx


@router.patch("/{tx_id}/card")
def assign_card(
    tx_id: int,
    payload: schemas.TransactionCardAssign,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    tx = (
        db.query(models.Transaction)
        .filter(models.Transaction.id == tx_id, models.Transaction.user_id == current_user.id)
        .first()
    )
    if tx is None:
        raise HTTPException(status_code=404, detail="找不到這筆交易")

    # Undo balance effect on old card
    if tx.card_id is not None:
        old_card = db.query(models.Card).filter(models.Card.id == tx.card_id).first()
        if old_card and old_card.balance is not None:
            old_card.balance -= tx.amount

    tx.card_id = payload.card_id

    # Apply balance effect on new card
    if payload.card_id is not None:
        new_card = (
            db.query(models.Card)
            .filter(models.Card.id == payload.card_id, models.Card.user_id == current_user.id)
            .first()
        )
        if new_card and new_card.balance is not None:
            new_card.balance += tx.amount

    db.commit()
    return {"status": "ok"}


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
