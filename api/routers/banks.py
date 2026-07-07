from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

import models
import schemas
from auth import get_current_user
from database import get_db

router = APIRouter(prefix="/banks", tags=["banks"])


@router.get("", response_model=list[schemas.BankRead])
def list_banks(
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return db.query(models.Bank).filter(models.Bank.user_id == current_user.id).all()


@router.post("", response_model=schemas.BankRead)
def create_bank(
    payload: schemas.BankCreate,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    bank = models.Bank(user_id=current_user.id, **payload.model_dump())
    db.add(bank)
    db.commit()
    db.refresh(bank)
    return bank


@router.put("/{bank_id}", response_model=schemas.BankRead)
def update_bank(
    bank_id: int,
    payload: schemas.BankUpdate,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    bank = (
        db.query(models.Bank)
        .filter(models.Bank.id == bank_id, models.Bank.user_id == current_user.id)
        .first()
    )
    if bank is None:
        raise HTTPException(status_code=404, detail="找不到這家銀行")
    for field, value in payload.model_dump().items():
        setattr(bank, field, value)
    db.commit()
    db.refresh(bank)
    return bank


@router.delete("/{bank_id}")
def delete_bank(
    bank_id: int,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    bank = (
        db.query(models.Bank)
        .filter(models.Bank.id == bank_id, models.Bank.user_id == current_user.id)
        .first()
    )
    if bank is None:
        raise HTTPException(status_code=404, detail="找不到這家銀行")
    db.delete(bank)
    db.commit()
    return {"status": "ok"}
