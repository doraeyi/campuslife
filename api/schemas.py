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
    picture: str | None = None


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


class ForgotPasswordRequest(BaseModel):
    email: EmailStr


class ResetPasswordRequest(BaseModel):
    email: EmailStr
    code: str
    new_password: str


class CardBase(BaseModel):
    name: str
    type: str
    color: str = "#6366F1"
    last_four: str | None = None
    bank: str | None = None
    balance: float | None = None
    due_amount: float | None = None
    credit_limit: float | None = None
    pass_expiry_date: str | None = None
    payment_due_date: str | None = None
    reminder_day: int | None = None
    credit_account_id: int | None = None

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
    job_id: int | None = None
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


class TransactionUpdate(BaseModel):
    amount: float | None = None
    description: str | None = None
    category: str | None = None
    note: str | None = None


class TransactionRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    card_id: int | None
    job_id: int | None
    amount: float
    description: str
    transaction_type: str
    category: str | None
    note: str | None
    is_cod: bool
    cod_paid: bool
    is_loan: bool
    loan_person: str | None
    transaction_date: date | None = None
    created_at: datetime
    card: "CardRead | None" = None


class BankBase(BaseModel):
    name: str


class BankCreate(BankBase):
    pass


class BankUpdate(BankBase):
    pass


class BankRead(BankBase):
    model_config = ConfigDict(from_attributes=True)

    id: int


class CreditAccountBase(BaseModel):
    bank_id: int
    name: str
    credit_limit: float
    billing_day: int | None = None
    due_day: int | None = None


class CreditAccountCreate(CreditAccountBase):
    pass


class CreditAccountUpdate(CreditAccountBase):
    pass


class CreditAccountRead(CreditAccountBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    bank: BankRead | None = None


class CreditAccountAvailable(BaseModel):
    credit_account_id: int
    credit_limit: float
    outstanding_balance: float
    available_credit: float


class StatementBase(BaseModel):
    credit_account_id: int
    period_start: date
    period_end: date
    statement_date: date
    due_date: date
    statement_amount: float
    minimum_due: float | None = None


class StatementCreate(StatementBase):
    pass


class StatementUpdate(StatementBase):
    pass


class StatementRead(BaseModel):
    id: int
    credit_account_id: int
    period_start: date
    period_end: date
    statement_date: date
    due_date: date
    statement_amount: float
    minimum_due: float | None
    paid_amount: float
    status: str


class PaymentCreate(BaseModel):
    statement_id: int | None = None
    from_account_id: int | None = None
    bank_name: str | None = None
    amount: float
    payment_date: date


class PaymentUpdate(BaseModel):
    statement_id: int | None = None
    from_account_id: int | None = None
    bank_name: str | None = None
    amount: float | None = None
    payment_date: date | None = None


class PaymentStatementAssign(BaseModel):
    statement_id: int | None = None


class PaymentRead(BaseModel):
    id: int
    statement_id: int | None
    from_account_id: int | None
    bank_name: str | None
    amount: float
    payment_date: date
    is_late: bool | None


class BankCreditSettingUpdate(BaseModel):
    billing_day: int | None = None
    starting_balance: float | None = None
    starting_balance_date: date | None = None


class BankCreditSettingRead(BaseModel):
    bank_name: str
    billing_day: int | None
    starting_balance: float | None
    starting_balance_date: date | None


class BankCreditSummary(BaseModel):
    bank_name: str
    credit_limit: float
    billing_day: int | None
    last_closing_date: date | None
    period_due_amount: float  # 本期應繳——結帳當下凍結的金額
    outstanding_now: float  # 目前實際欠多少（含結帳後新刷的），拿來算可用額度
    available_credit: float
    current_window_start_date: date | None  # 「最近紀錄」該從哪一天開始抓：
    # 從最近一次結帳日開始往前找，直到找到一期在結帳日之後的還款已經
    # 覆蓋掉那期的應繳金額為止，代表那期已經繳清了，之後的交易才算「這期」


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


class NotifyPendingRequest(BaseModel):
    summary: str


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
