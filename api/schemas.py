from datetime import date, datetime, time

from pydantic import BaseModel, ConfigDict, EmailStr


class JobBase(BaseModel):
    name: str
    color: str = "#6C63FF"
    pay_type: str = "hourly"
    hourly_rate: float | None = None
    monthly_salary: float | None = None
    payday: int | None = None
    labor_insurance_fee: float = 0
    health_insurance_fee: float = 0


class JobCreate(JobBase):
    pass


class JobUpdate(JobBase):
    pass


class JobRead(JobBase):
    model_config = ConfigDict(from_attributes=True)

    id: int


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
    pass_expiry_date: str | None = None
    payment_due_date: str | None = None


class CardCreate(CardBase):
    pass


class CardRead(CardBase):
    model_config = ConfigDict(from_attributes=True)

    id: int


class TransactionCreate(BaseModel):
    card_id: int | None = None
    amount: float
    description: str
    transaction_type: str  # "expense" | "income"
    category: str | None = None
    note: str | None = None
    date: str | None = None  # YYYY-MM-DD, defaults to today


class TransactionRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    card_id: int | None
    amount: float
    description: str
    transaction_type: str
    category: str | None
    note: str | None
    created_at: datetime
    card: "CardRead | None" = None


class CardBalanceUpdate(BaseModel):
    balance: float


class FriendRequestCreate(BaseModel):
    email: EmailStr


class FriendshipRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    status: str
    friend: UserRead
    incoming: bool
