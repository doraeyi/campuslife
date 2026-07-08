from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

import models
import schemas
from auth import get_current_user
from database import get_db

router = APIRouter(prefix="/payments", tags=["payments"])


def _validate_statement(db: Session, statement_id: int, user_id: int) -> models.Statement:
    statement = (
        db.query(models.Statement)
        .filter(models.Statement.id == statement_id, models.Statement.user_id == user_id)
        .first()
    )
    if statement is None:
        raise HTTPException(status_code=404, detail="找不到這張帳單")
    return statement


def _validate_from_account(db: Session, card_id: int, user_id: int) -> None:
    card = (
        db.query(models.Card)
        .filter(models.Card.id == card_id, models.Card.user_id == user_id)
        .first()
    )
    if card is None:
        raise HTTPException(status_code=404, detail="找不到這張卡片")


def _to_read(db: Session, p: models.Payment) -> schemas.PaymentRead:
    is_late = None
    if p.statement_id is not None:
        statement = db.query(models.Statement).filter(models.Statement.id == p.statement_id).first()
        if statement is not None:
            is_late = p.payment_date > statement.due_date
    return schemas.PaymentRead(
        id=p.id,
        statement_id=p.statement_id,
        from_account_id=p.from_account_id,
        bank_name=p.bank_name,
        amount=p.amount,
        payment_date=p.payment_date,
        is_late=is_late,
    )


@router.get("", response_model=list[schemas.PaymentRead])
def list_payments(
    statement_id: int | None = Query(None),
    bank_name: str | None = Query(None),
    unmatched: bool = Query(False),
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    q = db.query(models.Payment).filter(models.Payment.user_id == current_user.id)
    if unmatched:
        q = q.filter(models.Payment.statement_id.is_(None))
    elif statement_id is not None:
        q = q.filter(models.Payment.statement_id == statement_id)
    if bank_name is not None:
        q = q.filter(models.Payment.bank_name == bank_name)
    return [_to_read(db, p) for p in q.order_by(models.Payment.payment_date.desc()).all()]


@router.post("", response_model=schemas.PaymentRead)
def create_payment(
    payload: schemas.PaymentCreate,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if payload.statement_id is not None:
        _validate_statement(db, payload.statement_id, current_user.id)
    if payload.from_account_id is not None:
        _validate_from_account(db, payload.from_account_id, current_user.id)
    payment = models.Payment(user_id=current_user.id, **payload.model_dump())
    db.add(payment)
    db.commit()
    db.refresh(payment)
    return _to_read(db, payment)


@router.get("/{payment_id}", response_model=schemas.PaymentRead)
def get_payment(
    payment_id: int,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    payment = (
        db.query(models.Payment)
        .filter(models.Payment.id == payment_id, models.Payment.user_id == current_user.id)
        .first()
    )
    if payment is None:
        raise HTTPException(status_code=404, detail="找不到這筆還款紀錄")
    return _to_read(db, payment)


@router.patch("/{payment_id}", response_model=schemas.PaymentRead)
def update_payment(
    payment_id: int,
    payload: schemas.PaymentUpdate,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    payment = (
        db.query(models.Payment)
        .filter(models.Payment.id == payment_id, models.Payment.user_id == current_user.id)
        .first()
    )
    if payment is None:
        raise HTTPException(status_code=404, detail="找不到這筆還款紀錄")

    data = payload.model_dump(exclude_unset=True)
    if "statement_id" in data and data["statement_id"] is not None:
        _validate_statement(db, data["statement_id"], current_user.id)
    if "from_account_id" in data and data["from_account_id"] is not None:
        _validate_from_account(db, data["from_account_id"], current_user.id)
    for field, value in data.items():
        setattr(payment, field, value)
    db.commit()
    db.refresh(payment)
    return _to_read(db, payment)


@router.patch("/{payment_id}/statement", response_model=schemas.PaymentRead)
def assign_statement(
    payment_id: int,
    payload: schemas.PaymentStatementAssign,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    payment = (
        db.query(models.Payment)
        .filter(models.Payment.id == payment_id, models.Payment.user_id == current_user.id)
        .first()
    )
    if payment is None:
        raise HTTPException(status_code=404, detail="找不到這筆還款紀錄")
    if payload.statement_id is not None:
        _validate_statement(db, payload.statement_id, current_user.id)
    payment.statement_id = payload.statement_id
    db.commit()
    db.refresh(payment)
    return _to_read(db, payment)


@router.delete("/{payment_id}")
def delete_payment(
    payment_id: int,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    payment = (
        db.query(models.Payment)
        .filter(models.Payment.id == payment_id, models.Payment.user_id == current_user.id)
        .first()
    )
    if payment is None:
        raise HTTPException(status_code=404, detail="找不到這筆還款紀錄")
    db.delete(payment)
    db.commit()
    return {"status": "ok"}
