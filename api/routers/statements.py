from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import func
from sqlalchemy.orm import Session

import models
import schemas
from auth import get_current_user
from database import get_db

router = APIRouter(prefix="/statements", tags=["statements"])


def _validate_credit_account(db: Session, credit_account_id: int, user_id: int) -> None:
    account = (
        db.query(models.CreditAccount)
        .filter(models.CreditAccount.id == credit_account_id, models.CreditAccount.user_id == user_id)
        .first()
    )
    if account is None:
        raise HTTPException(status_code=404, detail="找不到這個信用帳戶")


def _to_read(db: Session, s: models.Statement) -> schemas.StatementRead:
    paid = db.query(func.sum(models.Payment.amount)).filter(
        models.Payment.statement_id == s.id
    ).scalar() or 0.0

    if paid >= s.statement_amount:
        status = "已繳清"
    elif date.today() > s.due_date:
        status = "逾期"
    else:
        status = "未繳清未逾期"

    return schemas.StatementRead(
        id=s.id,
        credit_account_id=s.credit_account_id,
        period_start=s.period_start,
        period_end=s.period_end,
        statement_date=s.statement_date,
        due_date=s.due_date,
        statement_amount=s.statement_amount,
        minimum_due=s.minimum_due,
        paid_amount=paid,
        status=status,
    )


@router.get("", response_model=list[schemas.StatementRead])
def list_statements(
    credit_account_id: int | None = Query(None),
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    q = db.query(models.Statement).filter(models.Statement.user_id == current_user.id)
    if credit_account_id is not None:
        q = q.filter(models.Statement.credit_account_id == credit_account_id)
    return [_to_read(db, s) for s in q.order_by(models.Statement.due_date.desc()).all()]


@router.post("", response_model=schemas.StatementRead)
def create_statement(
    payload: schemas.StatementCreate,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    _validate_credit_account(db, payload.credit_account_id, current_user.id)
    statement = models.Statement(user_id=current_user.id, **payload.model_dump())
    db.add(statement)
    db.commit()
    db.refresh(statement)
    return _to_read(db, statement)


@router.get("/{statement_id}", response_model=schemas.StatementRead)
def get_statement(
    statement_id: int,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    statement = (
        db.query(models.Statement)
        .filter(models.Statement.id == statement_id, models.Statement.user_id == current_user.id)
        .first()
    )
    if statement is None:
        raise HTTPException(status_code=404, detail="找不到這張帳單")
    return _to_read(db, statement)


@router.put("/{statement_id}", response_model=schemas.StatementRead)
def update_statement(
    statement_id: int,
    payload: schemas.StatementUpdate,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    statement = (
        db.query(models.Statement)
        .filter(models.Statement.id == statement_id, models.Statement.user_id == current_user.id)
        .first()
    )
    if statement is None:
        raise HTTPException(status_code=404, detail="找不到這張帳單")
    _validate_credit_account(db, payload.credit_account_id, current_user.id)
    for field, value in payload.model_dump().items():
        setattr(statement, field, value)
    db.commit()
    db.refresh(statement)
    return _to_read(db, statement)


@router.delete("/{statement_id}")
def delete_statement(
    statement_id: int,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    statement = (
        db.query(models.Statement)
        .filter(models.Statement.id == statement_id, models.Statement.user_id == current_user.id)
        .first()
    )
    if statement is None:
        raise HTTPException(status_code=404, detail="找不到這張帳單")
    db.delete(statement)
    db.commit()
    return {"status": "ok"}
