from datetime import date, datetime, time

from pydantic import BaseModel, ConfigDict, EmailStr, model_validator


class JobBase(BaseModel):
    name: str
    color: str = "#6C63FF"
    pay_type: str = "hourly"
    hourly_rate: float | None = None
    monthly_salary: float | None = None
    payday: int | None = None
    labor_insurance_fee: float = 0
    health_insurance_fee: float = 0
    welfare_fee: float = 0


class JobCreate(JobBase):
    pass


class JobUpdate(JobBase):
    pass


class ShiftPresetRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    label: str
    start_time: time
    end_time: time


class ShiftPresetCreate(BaseModel):
    label: str
    start_time: time
    end_time: time


class JobRead(JobBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    presets: list[ShiftPresetRead] = []


class JobPublicRead(BaseModel):
    """Job info safe to expose to friends/group-share viewers — no pay/insurance fields."""
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    color: str


class ShiftBase(BaseModel):
    date: date
    start_time: time
    end_time: time
    job_id: int | None = None
    shift_type: str | None = None
    note: str | None = None


class ShiftCreate(ShiftBase):
    pass


class ShiftRead(ShiftBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    job: JobRead | None = None


class ShiftFriendRead(ShiftBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    job: JobPublicRead | None = None


class IncomeCreate(BaseModel):
    job_id: int | None = None
    month: str
    gross_amount: float
    deduction_amount: float = 0
    note: str | None = None


class IncomeRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    job_id: int | None
    month: str
    gross_amount: float
    deduction_amount: float
    net_amount: float
    note: str | None
    job: JobRead | None = None


class UserCreate(BaseModel):
    email: EmailStr
    password: str
    display_name: str


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class GoogleAuthPayload(BaseModel):
    id_token: str | None = None
    access_token: str | None = None


class UserRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    email: EmailStr
    display_name: str


class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserRead


class UpdateProfile(BaseModel):
    display_name: str | None = None


class UserProfileRead(BaseModel):
    id: int
    email: str | None = None
    name: str | None = None
    picture: str | None = None


class UpdateProfilePayload(BaseModel):
    name: str | None = None
    picture: str | None = None


class GoogleLinkRead(BaseModel):
    linked: bool
    name: str | None = None
    picture: str | None = None


class LineLinkRead(BaseModel):
    linked: bool


class LineLinkCodeRead(BaseModel):
    code: str


class LineLinkConfirm(BaseModel):
    code: str
    line_user_id: str


class HasPasswordRead(BaseModel):
    has_password: bool


class PasswordUpdate(BaseModel):
    current_password: str
    new_password: str


class CardBase(BaseModel):
    name: str
    type: str
    color: str = "#6366F1"
    last_four: str | None = None
    bank: str | None = None
    balance: float | None = None
    due_amount: float | None = None
    pass_expiry_date: str | None = None
    payment_due_date: str | None = None
    reminder_day: int | None = None

    @model_validator(mode="after")
    def _validate_required_fields(self):
        if not self.last_four or len(self.last_four) != 4:
            raise ValueError("卡號後四碼為必填")
        if self.type != "easycard" and not self.bank:
            raise ValueError("銀行為必填")
        return self


class CardCreate(CardBase):
    pass


class CardUpdate(CardBase):
    pass


class CardRead(CardBase):
    model_config = ConfigDict(from_attributes=True)

    id: int


class TransactionCreate(BaseModel):
    card_id: int | None = None
    amount: float
    description: str | None = None
    transaction_type: str | None = None
    category: str | None = None
    note: str | None = None
    date: str | None = None
    is_cod: bool = False
    is_loan: bool = False
    loan_person: str | None = None
    # Next.js field aliases
    type: str | None = None
    category_id: str | None = None

    @model_validator(mode="after")
    def _validate_loan(self):
        if self.is_loan and not (self.loan_person and self.loan_person.strip()):
            raise ValueError("請填寫借款對象")
        return self

    @model_validator(mode="before")
    @classmethod
    def _normalize(cls, data):
        if not isinstance(data, dict):
            return data
        data = dict(data)
        if not data.get("transaction_type") and data.get("type"):
            data["transaction_type"] = data["type"]
        if data.get("category") is None and data.get("category_id") is not None:
            data["category"] = str(data["category_id"]) if data["category_id"] else "other"
        if not data.get("description") and data.get("note"):
            data["description"] = data["note"]
        return data


class TransactionCardAssign(BaseModel):
    card_id: int | None = None


class TransactionRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    card_id: int | None
    amount: float
    description: str
    transaction_type: str
    category: str | None
    note: str | None
    is_cod: bool
    cod_paid: bool
    is_loan: bool
    loan_person: str | None
    created_at: datetime
    card: "CardRead | None" = None


class CardBalanceUpdate(BaseModel):
    balance: float


class EinvoiceImportResult(BaseModel):
    imported: int
    skipped: int
    errors: list[str] = []


class PendingScreenshotRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    created_at: datetime


class FriendRequestCreate(BaseModel):
    email: EmailStr


class FriendshipRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    status: str
    friend: UserRead
    incoming: bool


class JobShareRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    shared_with: UserRead


class GroupShiftRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    date: date
    start_time: time
    end_time: time
    shift_type: str | None = None
    note: str | None = None
    job: JobPublicRead | None = None
    owner: UserRead
