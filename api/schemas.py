from datetime import date, time

from pydantic import BaseModel, ConfigDict


class ShiftBase(BaseModel):
    date: date
    start_time: time
    end_time: time
    note: str | None = None


class ShiftCreate(ShiftBase):
    pass


class ShiftRead(ShiftBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
