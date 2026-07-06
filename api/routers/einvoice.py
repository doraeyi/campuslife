import csv
import io
import re
from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, UploadFile

import models
import schemas
from auth import get_current_user
from database import get_db
from sqlalchemy.orm import Session

router = APIRouter(prefix="/einvoice", tags=["einvoice"])

# 財政部手機條碼專區匯出的 CSV 表頭沒有公開固定規格，這裡用關鍵字比對容錯
_INVOICE_NUMBER_ALIASES = ["發票號碼", "發票字軌", "字軌號碼"]
_RANDOM_CODE_ALIASES = ["隨機碼"]
_DATE_ALIASES = ["發票日期", "開立日期", "交易日期"]
_SELLER_ALIASES = ["賣方名稱", "商店名稱", "店家名稱", "賣方"]
_AMOUNT_ALIASES = ["總計金額", "總計", "銷售額", "金額"]
_STATUS_ALIASES = ["發票狀態", "狀態", "備註"]
_VOID_KEYWORDS = ["作廢", "捐贈"]

_DATE_FORMATS = ["%Y/%m/%d", "%Y-%m-%d", "%Y%m%d"]


def _find_column(headers: list[str], aliases: list[str]) -> Optional[int]:
    for i, h in enumerate(headers):
        stripped = (h or "").strip()
        if any(alias in stripped for alias in aliases):
            return i
    return None


def _parse_amount(raw: str) -> Optional[float]:
    cleaned = re.sub(r"[^\d.]", "", raw or "")
    if not cleaned:
        return None
    try:
        return float(cleaned)
    except ValueError:
        return None


def _parse_date(raw: str) -> Optional[datetime]:
    raw = (raw or "").strip()
    for fmt in _DATE_FORMATS:
        try:
            return datetime.strptime(raw, fmt)
        except ValueError:
            continue
    return None


def _decode_csv(raw: bytes) -> str:
    for encoding in ("utf-8-sig", "utf-8", "big5"):
        try:
            return raw.decode(encoding)
        except UnicodeDecodeError:
            continue
    raise HTTPException(status_code=400, detail="無法辨識 CSV 檔案編碼")


@router.post("/import", response_model=schemas.EinvoiceImportResult)
async def import_einvoice_csv(
    file: UploadFile,
    card_id: Optional[int] = Query(None),
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if card_id is not None:
        card = (
            db.query(models.Card)
            .filter(models.Card.id == card_id, models.Card.user_id == current_user.id)
            .first()
        )
        if card is None:
            raise HTTPException(status_code=404, detail="找不到這張卡片")
    else:
        card = None

    raw = await file.read()
    text = _decode_csv(raw)
    reader = csv.reader(io.StringIO(text))

    try:
        headers = next(reader)
    except StopIteration:
        raise HTTPException(status_code=400, detail="CSV 檔案是空的")

    col_invoice = _find_column(headers, _INVOICE_NUMBER_ALIASES)
    col_random = _find_column(headers, _RANDOM_CODE_ALIASES)
    col_date = _find_column(headers, _DATE_ALIASES)
    col_seller = _find_column(headers, _SELLER_ALIASES)
    col_amount = _find_column(headers, _AMOUNT_ALIASES)
    col_status = _find_column(headers, _STATUS_ALIASES)

    if col_invoice is None or col_amount is None:
        raise HTTPException(status_code=400, detail="CSV 欄位格式無法辨識（找不到發票號碼或金額欄位）")

    imported = 0
    skipped = 0
    errors: list[str] = []

    for row_num, row in enumerate(reader, start=2):
        if not row or all(not cell.strip() for cell in row):
            continue

        def cell(idx: Optional[int]) -> str:
            if idx is None or idx >= len(row):
                return ""
            return row[idx].strip()

        status_text = cell(col_status)
        if any(kw in status_text for kw in _VOID_KEYWORDS):
            skipped += 1
            continue

        invoice_number = cell(col_invoice)
        if not invoice_number:
            errors.append(f"第 {row_num} 列：缺少發票號碼")
            continue

        amount = _parse_amount(cell(col_amount))
        if amount is None:
            errors.append(f"第 {row_num} 列：金額格式錯誤")
            continue

        existing = (
            db.query(models.Transaction)
            .filter(
                models.Transaction.user_id == current_user.id,
                models.Transaction.einvoice_number == invoice_number,
            )
            .first()
        )
        if existing is not None:
            skipped += 1
            continue

        seller = cell(col_seller) or "電子發票"
        invoice_date = _parse_date(cell(col_date))
        random_code = cell(col_random) or None

        signed_amount = -abs(amount)
        tx = models.Transaction(
            user_id=current_user.id,
            card_id=card.id if card else None,
            amount=signed_amount,
            description=seller,
            transaction_type="expense",
            category="other",
            source="einvoice_csv",
            einvoice_number=invoice_number,
            einvoice_random_code=random_code,
        )
        if invoice_date is not None:
            tx.created_at = invoice_date
        db.add(tx)
        if card is not None and card.balance is not None:
            card.balance += signed_amount

        imported += 1

    db.commit()
    return schemas.EinvoiceImportResult(imported=imported, skipped=skipped, errors=errors)
