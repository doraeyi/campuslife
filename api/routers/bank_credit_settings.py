import calendar
from datetime import date

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

import models
import schemas
from auth import get_current_user
from database import get_db

router = APIRouter(prefix="/bank-credit-settings", tags=["bank-credit-settings"])


def _get_setting(db: Session, user_id: int, bank_name: str) -> models.BankCreditSetting | None:
    return (
        db.query(models.BankCreditSetting)
        .filter(models.BankCreditSetting.user_id == user_id, models.BankCreditSetting.bank_name == bank_name)
        .first()
    )


def _closing_date_for(year: int, month: int, billing_day: int) -> date:
    last_day_of_month = calendar.monthrange(year, month)[1]
    return date(year, month, min(billing_day, last_day_of_month))


def _last_closing_date(today: date, billing_day: int) -> date:
    this_month = _closing_date_for(today.year, today.month, billing_day)
    if today >= this_month:
        return this_month
    year, month = today.year, today.month - 1
    if month == 0:
        year, month = year - 1, 12
    return _closing_date_for(year, month, billing_day)


def _previous_closing_date(closing: date, billing_day: int) -> date:
    year, month = closing.year, closing.month - 1
    if month == 0:
        year, month = year - 1, 12
    return _closing_date_for(year, month, billing_day)


@router.get("/{bank_name}", response_model=schemas.BankCreditSettingRead)
def get_setting(
    bank_name: str,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    setting = _get_setting(db, current_user.id, bank_name)
    if setting is None:
        return schemas.BankCreditSettingRead(
            bank_name=bank_name, billing_day=None, starting_balance=None, starting_balance_date=None
        )
    return schemas.BankCreditSettingRead(
        bank_name=setting.bank_name,
        billing_day=setting.billing_day,
        starting_balance=setting.starting_balance,
        starting_balance_date=setting.starting_balance_date,
    )


@router.put("/{bank_name}", response_model=schemas.BankCreditSettingRead)
def update_setting(
    bank_name: str,
    payload: schemas.BankCreditSettingUpdate,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    setting = _get_setting(db, current_user.id, bank_name)
    if setting is None:
        setting = models.BankCreditSetting(user_id=current_user.id, bank_name=bank_name)
        db.add(setting)
    setting.billing_day = payload.billing_day
    setting.starting_balance = payload.starting_balance
    setting.starting_balance_date = payload.starting_balance_date
    db.commit()
    db.refresh(setting)
    return schemas.BankCreditSettingRead(
        bank_name=setting.bank_name,
        billing_day=setting.billing_day,
        starting_balance=setting.starting_balance,
        starting_balance_date=setting.starting_balance_date,
    )


@router.get("/{bank_name}/summary", response_model=schemas.BankCreditSummary)
def get_summary(
    bank_name: str,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    cards = (
        db.query(models.Card)
        .filter(
            models.Card.user_id == current_user.id,
            models.Card.type == "credit",
            models.Card.bank == bank_name,
        )
        .all()
    )
    if not cards:
        raise HTTPException(status_code=404, detail="找不到這家銀行的信用卡")

    card_ids = [c.id for c in cards]
    credit_limit = sum(c.credit_limit or 0 for c in cards)

    setting = _get_setting(db, current_user.id, bank_name)
    billing_day = setting.billing_day if setting else None
    starting_balance = (setting.starting_balance if setting and setting.starting_balance else 0.0)
    starting_date = setting.starting_balance_date if setting else None

    transactions = (
        db.query(models.Transaction)
        .filter(
            models.Transaction.user_id == current_user.id,
            models.Transaction.card_id.in_(card_ids),
            models.Transaction.transaction_type == "expense",
        )
        .all()
    )
    payments = (
        db.query(models.Payment)
        .filter(models.Payment.user_id == current_user.id, models.Payment.bank_name == bank_name)
        .all()
    )

    def effective_date(t: models.Transaction) -> date:
        return t.transaction_date or t.created_at.date()

    def outstanding_as_of(cutoff: date) -> float:
        total = starting_balance
        for t in transactions:
            d = effective_date(t)
            if starting_date is not None and d <= starting_date:
                continue
            if d <= cutoff:
                total += abs(t.amount)
        for p in payments:
            if starting_date is not None and p.payment_date <= starting_date:
                continue
            if p.payment_date <= cutoff:
                total -= p.amount
        return total

    today = date.today()
    last_closing = _last_closing_date(today, billing_day) if billing_day else None
    period_due_amount = outstanding_as_of(last_closing) if last_closing else 0.0
    outstanding_now = outstanding_as_of(today)

    # 「最近紀錄」該從哪天開始抓：從最近一次結帳日往前找，直到找到某一期
    # 結帳後的還款金額已經蓋過那期的應繳金額（代表那期繳清了），
    # 從那之後的交易才算是目前這期還沒繳清的部分
    current_window_start = None
    if billing_day and last_closing is not None:
        cutoff = last_closing
        while True:
            due_at_cutoff = outstanding_as_of(cutoff)
            paid_after = sum(p.amount for p in payments if p.payment_date > cutoff)
            if due_at_cutoff <= 0.01 or paid_after >= due_at_cutoff - 0.01:
                current_window_start = cutoff
                break
            prev_cutoff = _previous_closing_date(cutoff, billing_day)
            if starting_date is not None and prev_cutoff <= starting_date:
                current_window_start = starting_date
                break
            if prev_cutoff >= cutoff:
                # 安全防呆：避免結帳日設定異常造成無限迴圈
                current_window_start = starting_date
                break
            cutoff = prev_cutoff

    return schemas.BankCreditSummary(
        bank_name=bank_name,
        credit_limit=credit_limit,
        billing_day=billing_day,
        last_closing_date=last_closing,
        period_due_amount=period_due_amount,
        outstanding_now=outstanding_now,
        available_credit=credit_limit - outstanding_now,
        current_window_start_date=current_window_start,
    )
