from sqlalchemy import Boolean, Column, Date, DateTime, Float, ForeignKey, Integer, String, Text, Time, UniqueConstraint
from sqlalchemy.dialects.mysql import LONGBLOB
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from database import Base


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String(255), unique=True, index=True, nullable=False)
    password_hash = Column(String(255), nullable=True)
    display_name = Column(String(100), nullable=False)
    picture = Column(Text, nullable=True)
    google_id = Column(String(255), nullable=True, unique=True)
    line_user_id = Column(String(255), nullable=True, unique=True)
    line_link_code = Column(String(10), nullable=True)
    line_link_code_expires_at = Column(DateTime(timezone=True), nullable=True)
    reset_code = Column(String(10), nullable=True)
    reset_code_expires_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime, server_default=func.now())


class Job(Base):
    __tablename__ = "jobs"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    name = Column(String(100), nullable=False)
    color = Column(String(7), nullable=False, default="#6C63FF")
    pay_type = Column(String(10), nullable=False, default="hourly")
    hourly_rate = Column(Float, nullable=True)
    monthly_salary = Column(Float, nullable=True)
    payday = Column(Integer, nullable=True)
    labor_insurance_fee = Column(Float, nullable=False, default=0)
    health_insurance_fee = Column(Float, nullable=False, default=0)
    welfare_fee = Column(Float, nullable=False, default=0)
    created_at = Column(DateTime, server_default=func.now())

    presets = relationship(
        "ShiftPreset", cascade="all, delete-orphan",
        order_by="ShiftPreset.id", lazy="selectin",
    )


class ShiftPreset(Base):
    __tablename__ = "shift_presets"

    id = Column(Integer, primary_key=True, index=True)
    job_id = Column(Integer, ForeignKey("jobs.id", ondelete="CASCADE"), nullable=False, index=True)
    label = Column(String(20), nullable=False)
    start_time = Column(Time, nullable=False)
    end_time = Column(Time, nullable=False)


class Bank(Base):
    __tablename__ = "banks"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    name = Column(String(100), nullable=False)
    created_at = Column(DateTime, server_default=func.now())


class CreditAccount(Base):
    """一組信用額度——可能只對應一張卡（獨立額度），也可能對應多張卡（共用額度）。"""
    __tablename__ = "credit_accounts"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    bank_id = Column(Integer, ForeignKey("banks.id"), nullable=False, index=True)
    name = Column(String(100), nullable=False)
    credit_limit = Column(Float, nullable=False)
    billing_day = Column(Integer, nullable=True)  # 結帳日
    due_day = Column(Integer, nullable=True)  # 繳款日
    created_at = Column(DateTime, server_default=func.now())

    bank = relationship("Bank")


class Card(Base):
    __tablename__ = "cards"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    name = Column(String(100), nullable=False)
    type = Column(String(20), nullable=False)
    color = Column(String(7), nullable=False, default="#6366F1")
    last_four = Column(String(4), nullable=True)
    bank = Column(String(100), nullable=True)
    balance = Column(Float, nullable=True)
    due_amount = Column(Float, nullable=True)
    credit_limit = Column(Float, nullable=True)
    pass_expiry_date = Column(String(10), nullable=True)
    payment_due_date = Column(String(10), nullable=True)
    reminder_day = Column(Integer, nullable=True)
    credit_account_id = Column(Integer, ForeignKey("credit_accounts.id"), nullable=True, index=True)
    created_at = Column(DateTime, server_default=func.now())

    credit_account = relationship("CreditAccount")


class Shift(Base):
    __tablename__ = "shifts"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    job_id = Column(Integer, ForeignKey("jobs.id"), nullable=True, index=True)
    date = Column(Date, nullable=False)
    start_time = Column(Time, nullable=False)
    end_time = Column(Time, nullable=False)
    shift_type = Column(String(20), nullable=True)
    note = Column(String(255), nullable=True)

    owner = relationship("User")
    job = relationship("Job")


class Income(Base):
    __tablename__ = "incomes"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    job_id = Column(Integer, ForeignKey("jobs.id"), nullable=True, index=True)
    month = Column(String(7), nullable=False)
    gross_amount = Column(Float, nullable=False)
    deduction_amount = Column(Float, nullable=False, default=0)
    net_amount = Column(Float, nullable=False)
    note = Column(String(255), nullable=True)
    created_at = Column(DateTime, server_default=func.now())

    job = relationship("Job")


class Transaction(Base):
    __tablename__ = "transactions"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    card_id = Column(Integer, ForeignKey("cards.id"), nullable=True, index=True)
    job_id = Column(Integer, ForeignKey("jobs.id"), nullable=True, index=True)
    amount = Column(Float, nullable=False)  # 正數=收入, 負數=支出
    description = Column(String(100), nullable=False)
    transaction_type = Column(String(20), nullable=False)  # "expense" | "income"
    category = Column(String(20), nullable=True)
    note = Column(String(255), nullable=True)
    is_cod = Column(Boolean, nullable=False, default=False)
    cod_paid = Column(Boolean, nullable=False, default=False)
    is_loan = Column(Boolean, nullable=False, default=False)
    loan_person = Column(String(50), nullable=True)
    source = Column(String(20), nullable=False, default="manual")  # manual | einvoice_csv | line_bot | bank_notification
    einvoice_number = Column(String(10), nullable=True, index=True)
    einvoice_random_code = Column(String(4), nullable=True)
    transaction_date = Column(Date, nullable=True)  # 實際消費日期，跟 created_at（寫入時間）分開
    created_at = Column(DateTime, server_default=func.now())

    card = relationship("Card")
    job = relationship("Job")

    __table_args__ = (UniqueConstraint("user_id", "einvoice_number", name="uq_transaction_user_einvoice"),)


class Statement(Base):
    """一期帳單——涵蓋整個 CreditAccount（額度群組）底下所有卡片的消費，不是單卡各一張。"""
    __tablename__ = "statements"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    credit_account_id = Column(Integer, ForeignKey("credit_accounts.id"), nullable=False, index=True)
    period_start = Column(Date, nullable=False)
    period_end = Column(Date, nullable=False)
    statement_date = Column(Date, nullable=False)
    due_date = Column(Date, nullable=False)
    statement_amount = Column(Float, nullable=False)
    minimum_due = Column(Float, nullable=True)
    created_at = Column(DateTime, server_default=func.now())

    credit_account = relationship("CreditAccount")


class Payment(Base):
    """還款紀錄，跟 Statement 分開存——可以先繳款，之後才配對到某一期帳單。"""
    __tablename__ = "payments"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    statement_id = Column(Integer, ForeignKey("statements.id"), nullable=True, index=True)
    from_account_id = Column(Integer, ForeignKey("cards.id"), nullable=True, index=True)
    bank_name = Column(String(100), nullable=True, index=True)  # 對應 Card.bank 這個自由文字欄位，還款不綁定單一張卡
    amount = Column(Float, nullable=False)
    payment_date = Column(Date, nullable=False)
    created_at = Column(DateTime, server_default=func.now())

    statement = relationship("Statement")
    from_account = relationship("Card")


class BankCreditSetting(Base):
    """信用卡結帳週期設定，依銀行名稱歸戶（不是實體 Bank/CreditAccount 資料表）。
    billing_day：結帳日（幾號），用來把交易切成「本期」跟「下期」。
    starting_balance / starting_balance_date：起始基準點——因為 App 只看得到
    使用者開始用這個功能之後的交易，所以需要一個「當下實際欠多少」的起點，
    之後才能接著正確滾動累計。
    """
    __tablename__ = "bank_credit_settings"
    __table_args__ = (UniqueConstraint("user_id", "bank_name", name="uq_bank_credit_setting"),)

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    bank_name = Column(String(100), nullable=False)
    billing_day = Column(Integer, nullable=True)
    starting_balance = Column(Float, nullable=True)
    starting_balance_date = Column(Date, nullable=True)
    created_at = Column(DateTime, server_default=func.now())


class PendingBankScreenshot(Base):
    """截圖轉傳給 LINE Bot 後暫存在這裡，等使用者打開 App 用手機本機 OCR 辨識、確認建立交易。"""
    __tablename__ = "pending_bank_screenshots"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    image_data = Column(LONGBLOB, nullable=False)
    content_type = Column(String(50), nullable=False, default="image/jpeg")
    created_at = Column(DateTime, server_default=func.now())


class Friendship(Base):
    __tablename__ = "friendships"
    __table_args__ = (UniqueConstraint("user_id", "friend_id", name="uq_friendship_pair"),)

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    friend_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    status = Column(String(20), nullable=False, default="pending")
    created_at = Column(DateTime, server_default=func.now())


class JobShare(Base):
    __tablename__ = "job_shares"
    __table_args__ = (UniqueConstraint("job_id", "shared_with_id", name="uq_job_share"),)

    id = Column(Integer, primary_key=True, index=True)
    job_id = Column(Integer, ForeignKey("jobs.id", ondelete="CASCADE"), nullable=False, index=True)
    owner_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    shared_with_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    created_at = Column(DateTime, server_default=func.now())

    job = relationship("Job")
    shared_with = relationship("User", foreign_keys=[shared_with_id])
