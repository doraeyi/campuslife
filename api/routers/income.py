from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

import models
import schemas
from auth import get_current_user
from database import get_db

router = APIRouter(prefix="/income", tags=["income"])


@router.get("", response_model=list[schemas.IncomeRead])
def list_income(
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return (
        db.query(models.Income)
        .filter(models.Income.user_id == current_user.id)
        .order_by(models.Income.month.desc())
        .all()
    )


@router.post("", response_model=schemas.IncomeRead)
def create_income(
    payload: schemas.IncomeCreate,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    net_amount = payload.gross_amount - payload.deduction_amount
    income = models.Income(
        user_id=current_user.id,
        job_id=payload.job_id,
        month=payload.month,
        gross_amount=payload.gross_amount,
        deduction_amount=payload.deduction_amount,
        net_amount=net_amount,
        note=payload.note,
    )
    db.add(income)
    db.commit()
    db.refresh(income)
    return income


@router.delete("/{income_id}")
def delete_income(
    income_id: int,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    income = (
        db.query(models.Income)
        .filter(models.Income.id == income_id, models.Income.user_id == current_user.id)
        .first()
    )
    if income is None:
        return {"status": "not_found"}
    db.delete(income)
    db.commit()
    return {"status": "ok"}
