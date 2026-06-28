from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

import models
import schemas
from database import get_db

router = APIRouter(prefix="/schedule", tags=["schedule"])


@router.get("", response_model=list[schemas.ShiftRead])
def list_shifts(db: Session = Depends(get_db)):
    return db.query(models.Shift).order_by(models.Shift.date).all()


@router.post("", response_model=schemas.ShiftRead)
def create_shift(shift: schemas.ShiftCreate, db: Session = Depends(get_db)):
    db_shift = models.Shift(**shift.model_dump())
    db.add(db_shift)
    db.commit()
    db.refresh(db_shift)
    return db_shift
