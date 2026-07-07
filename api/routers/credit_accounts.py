from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func
from sqlalchemy.orm import Session

import models
import schemas
from auth import get_current_user
from database import get_db

router = APIRouter(prefix="/credit-accounts", tags=["credit-accounts"])


def _validate_bank(db: Session, bank_id: int, user_id: int) -> None:
    bank = (
        db.query(models.Bank)
        .filter(models.Bank.id == bank_id, models.Bank.user_id == user_id)
        .first()
    )
    if bank is None:
        raise HTTPException(status_code=404, detail="找不到這家銀行")


@router.get("", response_model=list[schemas.CreditAccountRead])
def list_credit_accounts(
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return (
        db.query(models.CreditAccount)
        .filter(models.CreditAccount.user_id == current_user.id)
        .all()
    )


@router.post("", response_model=schemas.CreditAccountRead)
def create_credit_account(
    payload: schemas.CreditAccountCreate,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    _validate_bank(db, payload.bank_id, current_user.id)
    account = models.CreditAccount(user_id=current_user.id, **payload.model_dump())
    db.add(account)
    db.commit()
    db.refresh(account)
    return account


@router.put("/{account_id}", response_model=schemas.CreditAccountRead)
def update_credit_account(
    account_id: int,
    payload: schemas.CreditAccountUpdate,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    account = (
        db.query(models.CreditAccount)
        .filter(models.CreditAccount.id == account_id, models.CreditAccount.user_id == current_user.id)
        .first()
    )
    if account is None:
        raise HTTPException(status_code=404, detail="找不到這個信用帳戶")
    _validate_bank(db, payload.bank_id, current_user.id)
    for field, value in payload.model_dump().items():
        setattr(account, field, value)
    db.commit()
    db.refresh(account)
    return account


@router.delete("/{account_id}")
def delete_credit_account(
    account_id: int,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    account = (
        db.query(models.CreditAccount)
        .filter(models.CreditAccount.id == account_id, models.CreditAccount.user_id == current_user.id)
        .first()
    )
    if account is None:
        raise HTTPException(status_code=404, detail="找不到這個信用帳戶")
    db.delete(account)
    db.commit()
    return {"status": "ok"}


@router.get("/{account_id}/available-credit", response_model=schemas.CreditAccountAvailable)
def get_available_credit(
    account_id: int,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    account = (
        db.query(models.CreditAccount)
        .filter(models.CreditAccount.id == account_id, models.CreditAccount.user_id == current_user.id)
        .first()
    )
    if account is None:
        raise HTTPException(status_code=404, detail="找不到這個信用帳戶")

    card_ids = [
        c.id for c in db.query(models.Card.id).filter(models.Card.credit_account_id == account.id).all()
    ]
    spent = 0.0
    if card_ids:
        spent = db.query(func.sum(func.abs(models.Transaction.amount))).filter(
            models.Transaction.card_id.in_(card_ids),
            models.Transaction.transaction_type == "expense",
        ).scalar() or 0.0

    statement_ids = [
        s.id for s in db.query(models.Statement.id)
        .filter(models.Statement.credit_account_id == account.id).all()
    ]
    paid = 0.0
    if statement_ids:
        paid = db.query(func.sum(models.Payment.amount)).filter(
            models.Payment.statement_id.in_(statement_ids),
        ).scalar() or 0.0

    outstanding = spent - paid
    return schemas.CreditAccountAvailable(
        credit_account_id=account.id,
        credit_limit=account.credit_limit,
        outstanding_balance=outstanding,
        available_credit=account.credit_limit - outstanding,
    )
