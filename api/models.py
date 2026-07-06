from sqlalchemy import Boolean, Column, Date, DateTime, Float, ForeignKey, Integer, LargeBinary, String, Text, Time, UniqueConstraint
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
    pass_expiry_date = Column(String(10), nullable=True)
    payment_due_date = Column(String(10), nullable=True)
    reminder_day = Column(Integer, nullable=True)
    created_at = Column(DateTime, server_default=func.now())


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
    created_at = Column(DateTime, server_default=func.now())

    card = relationship("Card")

    __table_args__ = (UniqueConstraint("user_id", "einvoice_number", name="uq_transaction_user_einvoice"),)


class PendingBankScreenshot(Base):
    """截圖轉傳給 LINE Bot 後暫存在這裡，等使用者打開 App 用手機本機 OCR 辨識、確認建立交易。"""
    __tablename__ = "pending_bank_screenshots"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    image_data = Column(LargeBinary, nullable=False)
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
