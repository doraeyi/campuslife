import calendar
from datetime import date, timedelta

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import and_, or_
from sqlalchemy.orm import Session

import models
import schemas
from auth import get_current_user
from database import get_db

router = APIRouter(prefix="/bank-credit-settings", tags=["bank-credit-settings"])

_MAX_LOOKBACK_PERIODS = 3  # 「待處理帳單」只往前看 3 期（大約 3 個月）


def _get_setting(db: Session, user_id: int, group_key: str) -> models.BankCreditSetting | None:
    return (
        db.query(models.BankCreditSetting)
        .filter(models.BankCreditSetting.user_id == user_id, models.BankCreditSetting.bank_name == group_key)
        .first()
    )


def _cards_for_group(db: Session, user_id: int, group_key: str) -> list[models.Card]:
    """group_key 通常就是銀行名稱；沒設定 credit_group_key 的舊卡片，退回用
    Card.bank 比對（等同「預設共用」）。"""
    return (
        db.query(models.Card)
        .filter(
            models.Card.user_id == user_id,
            models.Card.type == "credit",
            or_(
                models.Card.credit_group_key == group_key,
                and_(models.Card.credit_group_key.is_(None), models.Card.bank == group_key),
            ),
        )
        .all()
    )


def _closing_date_for(year: int, month: int, billing_day: int) -> date:
    last_day_of_month = calendar.monthrange(year, month)[1]
    return date(year, month, min(billing_day, last_day_of_month))


def _last_closing_date(today: date, billing_day: int) -> date:
    """今天(含)之前，最近一次的結帳日。今天剛好是結帳日也算。"""
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


def _effective_date(t: models.Transaction) -> date:
    return t.transaction_date or t.created_at.date()


def _period_amount(
    transactions: list[models.Transaction], start_inclusive: date | None, end_exclusive: date | None
) -> float:
    """一期涵蓋 [start_inclusive, end_exclusive)——結帳日當天算進「新的一期」，不算進舊的那期。"""
    total = 0.0
    for t in transactions:
        d = _effective_date(t)
        if start_inclusive is not None and d < start_inclusive:
            continue
        if end_exclusive is not None and d >= end_exclusive:
            continue
        total += abs(t.amount)
    return total


def _is_period_paid(payments: list[models.Payment], closing_date: date) -> bool:
    return any(p.period_closing_date == closing_date for p in payments)


@router.get("/{bank_name}", response_model=schemas.BankCreditSettingRead)
def get_setting(
    bank_name: str,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    setting = _get_setting(db, current_user.id, bank_name)
    return schemas.BankCreditSettingRead(
        bank_name=bank_name,
        billing_day=setting.billing_day if setting else None,
        manual_period_amount=setting.manual_period_amount if setting else None,
        manual_period_set_date=setting.manual_period_set_date if setting else None,
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
    if payload.manual_period_amount is not None:
        setting.manual_period_amount = payload.manual_period_amount
        setting.manual_period_set_date = date.today()
    else:
        setting.manual_period_amount = None
        setting.manual_period_set_date = None
    db.commit()
    db.refresh(setting)
    return schemas.BankCreditSettingRead(
        bank_name=setting.bank_name,
        billing_day=setting.billing_day,
        manual_period_amount=setting.manual_period_amount,
        manual_period_set_date=setting.manual_period_set_date,
    )


@router.get("/{bank_name}/summary", response_model=schemas.BankCreditSummary)
def get_summary(
    bank_name: str,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    cards = _cards_for_group(db, current_user.id, bank_name)
    if not cards:
        raise HTTPException(status_code=404, detail="找不到這家銀行的信用卡")

    card_ids = [c.id for c in cards]
    credit_limit = sum(c.credit_limit or 0 for c in cards)

    setting = _get_setting(db, current_user.id, bank_name)
    billing_day = setting.billing_day if setting else None

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

    today = date.today()
    current_period_spend = 0.0
    unpaid_bills: list[schemas.BankBillRead] = []

    last_closing: date | None = None
    if billing_day:
        last_closing = _last_closing_date(today, billing_day)

        # 手動覆蓋「目前本期花了多少」：只在還是同一期（還沒換結帳日）才有效，
        # 一旦結帳日換過一輪就自動失效，回到單純加總交易
        manual_valid = (
            setting is not None
            and setting.manual_period_amount is not None
            and setting.manual_period_set_date is not None
            and _last_closing_date(setting.manual_period_set_date, billing_day) == last_closing
        )
        if manual_valid:
            # 跟覆蓋同一天的交易也算「之後新記的」——寧可可能重複算一點，
            # 也不要把使用者當天後來才記的新交易漏算
            new_since_manual = _period_amount(
                transactions, setting.manual_period_set_date, today + timedelta(days=1)
            )
            current_period_spend = setting.manual_period_amount + new_since_manual
        else:
            current_period_spend = _period_amount(transactions, last_closing, today + timedelta(days=1))

        cutoff = last_closing
        for _ in range(_MAX_LOOKBACK_PERIODS):
            prev_cutoff = _previous_closing_date(cutoff, billing_day)
            amount = _period_amount(transactions, prev_cutoff, cutoff)
            if amount > 0.01 and not _is_period_paid(payments, cutoff):
                unpaid_bills.append(schemas.BankBillRead(
                    closing_date=cutoff, period_start=prev_cutoff, period_end=cutoff,
                    amount=amount, paid=False,
                ))
            cutoff = prev_cutoff

    return schemas.BankCreditSummary(
        bank_name=bank_name,
        credit_limit=credit_limit,
        billing_day=billing_day,
        last_closing_date=last_closing,
        current_period_spend=current_period_spend,
        available_credit=credit_limit - current_period_spend,
        unpaid_bills=unpaid_bills,
    )


@router.post("/{bank_name}/bills/{closing_date}/pay", response_model=schemas.BankBillRead)
def pay_bill(
    bank_name: str,
    closing_date: date,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    cards = _cards_for_group(db, current_user.id, bank_name)
    if not cards:
        raise HTTPException(status_code=404, detail="找不到這家銀行的信用卡")

    setting = _get_setting(db, current_user.id, bank_name)
    if not setting or not setting.billing_day:
        raise HTTPException(status_code=400, detail="還沒設定結帳日")

    existing = (
        db.query(models.Payment)
        .filter(
            models.Payment.user_id == current_user.id,
            models.Payment.bank_name == bank_name,
            models.Payment.period_closing_date == closing_date,
        )
        .first()
    )
    if existing is not None:
        raise HTTPException(status_code=400, detail="這期已經標記過已繳")

    period_start = _previous_closing_date(closing_date, setting.billing_day)
    card_ids = [c.id for c in cards]
    transactions = (
        db.query(models.Transaction)
        .filter(
            models.Transaction.user_id == current_user.id,
            models.Transaction.card_id.in_(card_ids),
            models.Transaction.transaction_type == "expense",
        )
        .all()
    )
    amount = _period_amount(transactions, period_start, closing_date)
    if amount <= 0:
        raise HTTPException(status_code=400, detail="這期沒有消費紀錄")

    payment = models.Payment(
        user_id=current_user.id,
        bank_name=bank_name,
        period_closing_date=closing_date,
        amount=amount,
        payment_date=date.today(),
    )
    db.add(payment)
    db.commit()

    return schemas.BankBillRead(
        closing_date=closing_date, period_start=period_start, period_end=closing_date, amount=amount, paid=True,
    )
