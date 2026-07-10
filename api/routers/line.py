import os
import random
import re
import string
import urllib.parse
from datetime import datetime, timedelta, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy.orm import Session

import models
import schemas
from auth import create_access_token, get_current_user
from database import get_db

router = APIRouter(prefix="/line", tags=["line"])

# ── LINE SDK setup ────────────────────────────────────────────────────────────
try:
    from linebot.v3 import WebhookParser
    from linebot.v3.exceptions import InvalidSignatureError
    from linebot.v3.messaging import (
        ApiClient as LineApiClient,
        Configuration as LineConfiguration,
        MessagingApi,
        MessagingApiBlob,
        PostbackAction,
        PushMessageRequest,
        QuickReply,
        QuickReplyItem,
        ReplyMessageRequest,
        TextMessage,
    )
    from linebot.v3.webhooks import ImageMessageContent, MessageEvent, PostbackEvent, TextMessageContent

    _channel_secret = os.getenv("LINE_CHANNEL_SECRET", "")
    _channel_token = os.getenv("LINE_CHANNEL_ACCESS_TOKEN", "")
    _parser = WebhookParser(_channel_secret)
    _line_config = LineConfiguration(access_token=_channel_token)
    _LINE_AVAILABLE = True
except ImportError:
    _LINE_AVAILABLE = False


def push_message(line_user_id: str, text: str):
    """Proactively send the user a LINE message (not tied to a reply token —
    used when we've finished processing something asynchronously, e.g. the
    app auto-recording a bank-notify screenshot well after the original
    webhook event's reply token has expired)."""
    if not _LINE_AVAILABLE:
        return
    with LineApiClient(_line_config) as client:
        MessagingApi(client).push_message(
            PushMessageRequest(to=line_user_id, messages=[TextMessage(text=text)])
        )


# ── App 端：帳號連結管理 ─────────────────────────────────────────────────────

@router.get("/link", response_model=schemas.LineLinkRead)
def get_line_link(current_user: models.User = Depends(get_current_user)):
    return schemas.LineLinkRead(linked=current_user.line_user_id is not None)


@router.post("/link", response_model=schemas.LineLinkCodeRead)
def create_line_code(
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    code = "".join(random.choices(string.digits, k=6))
    current_user.line_link_code = code
    current_user.line_link_code_expires_at = datetime.now(timezone.utc) + timedelta(minutes=5)
    db.commit()
    return schemas.LineLinkCodeRead(code=code)


@router.delete("/link")
def unlink_line(
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    current_user.line_user_id = None
    db.commit()
    return {"status": "ok"}


# ── Next.js 相容端點 ─────────────────────────────────────────────────────────

@router.get("/link/status", response_model=schemas.LineLinkRead)
def get_line_link_status(current_user: models.User = Depends(get_current_user)):
    return schemas.LineLinkRead(linked=current_user.line_user_id is not None)


@router.post("/link/generate", response_model=schemas.LineLinkCodeRead)
def generate_line_code(
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    code = "".join(random.choices(string.digits, k=6))
    current_user.line_link_code = code
    current_user.line_link_code_expires_at = datetime.now(timezone.utc) + timedelta(minutes=5)
    db.commit()
    return schemas.LineLinkCodeRead(code=code)


@router.post("/link/confirm")
def confirm_line_link(payload: schemas.LineLinkConfirm, db: Session = Depends(get_db)):
    now = datetime.now(timezone.utc)
    target = (
        db.query(models.User)
        .filter(
            models.User.line_link_code == payload.code,
            models.User.line_link_code_expires_at > now,
        )
        .first()
    )
    if target is None:
        raise HTTPException(status_code=404, detail="綁定碼無效或已過期")
    target.line_user_id = payload.line_user_id
    target.line_link_code = None
    target.line_link_code_expires_at = None
    db.commit()
    return {"status": "ok"}


@router.get("/token")
def get_token_for_line_user(
    line_user_id: str = Query(...),
    db: Session = Depends(get_db),
):
    user = db.query(models.User).filter(models.User.line_user_id == line_user_id).first()
    if user is None:
        raise HTTPException(status_code=404, detail="找不到綁定帳號")
    return {"token": create_access_token(user.id)}


@router.post("/pending/increment")
def increment_pending(line_user_id: str = Query(...)):
    return {"status": "ok"}


# ── LINE Webhook ──────────────────────────────────────────────────────────────

@router.post("/webhook")
async def line_webhook(request: Request, db: Session = Depends(get_db)):
    if not _LINE_AVAILABLE:
        raise HTTPException(status_code=503, detail="LINE SDK not installed")

    body = await request.body()
    signature = request.headers.get("X-Line-Signature", "")

    try:
        events = _parser.parse(body.decode("utf-8"), signature)
    except InvalidSignatureError:
        raise HTTPException(status_code=400, detail="Invalid signature")

    for event in events:
        if isinstance(event, MessageEvent) and isinstance(event.message, TextMessageContent):
            _handle_text(event.message.text, event.source.user_id, event.reply_token, db)
        elif isinstance(event, MessageEvent) and isinstance(event.message, ImageMessageContent):
            _handle_image(event.message.id, event.source.user_id, event.reply_token, db)
        elif isinstance(event, PostbackEvent):
            _handle_postback(event.postback.data, event.source.user_id, event.reply_token, db)

    return {"status": "ok"}


# ── 內部 helpers ──────────────────────────────────────────────────────────────

def _reply(reply_token: str, text: str, quick_reply=None):
    msg = TextMessage(text=text, quick_reply=quick_reply)
    with LineApiClient(_line_config) as client:
        MessagingApi(client).reply_message_with_http_info(
            ReplyMessageRequest(reply_token=reply_token, messages=[msg])
        )


def _card_emoji(card_type: str) -> str:
    return {"credit": "💳", "easycard": "🎫", "debit": "🏦"}.get(card_type, "💳")


def _fuzzy_match_card(keyword: str, cards: list) -> Optional[models.Card]:
    kw = keyword.strip().lower()
    type_map = {"悠遊": "easycard", "信用": "credit", "金融": "debit", "easycard": "easycard"}
    for k, t in type_map.items():
        if k in kw:
            matched = [c for c in cards if c.type == t]
            if matched:
                return matched[0]
    for card in cards:
        if kw in card.name.lower():
            return card
    return None


def _handle_text(text: str, line_user_id: str, reply_token: str, db: Session):
    text = text.strip()
    user: Optional[models.User] = (
        db.query(models.User).filter(models.User.line_user_id == line_user_id).first()
    )

    # ── 帳號綁定 ──────────────────────────────────────────────────────────────
    bind_match = re.match(r"^綁定\s+(\d{6})$", text)
    if bind_match:
        code = bind_match.group(1)
        now = datetime.now(timezone.utc)
        target = (
            db.query(models.User)
            .filter(
                models.User.line_link_code == code,
                models.User.line_link_code_expires_at > now,
            )
            .first()
        )
        if target is None:
            _reply(reply_token, "❌ 綁定碼無效或已過期，請在 App 的設定重新產生。")
            return
        target.line_user_id = line_user_id
        target.line_link_code = None
        target.line_link_code_expires_at = None
        db.commit()
        _reply(reply_token, f"✅ 綁定成功！你好 {target.display_name}～\n之後就可以傳「茶葉蛋 10」直接記帳，傳「餘額」查看各卡餘額。")
        return

    if user is None:
        _reply(reply_token, "你還沒綁定帳號！\n請在 App 設定頁產生綁定碼，再傳「綁定 XXXXXX」給我。")
        return

    # ── 排班表照片匯入：先傳「班表」開啟短效模式，接下來收到的第一張圖片會被
    # 當成排班表照片處理，而不是預設的銀行通知截圖，見 _handle_image。 ─────────
    if text in ("班表", "排班表"):
        user.roster_import_expected_until = datetime.now(timezone.utc) + timedelta(minutes=10)
        db.commit()
        _reply(reply_token, "好的，接下來收到的照片會當作班表匯入（10 分鐘內有效）📋")
        return

    cards = db.query(models.Card).filter(models.Card.user_id == user.id).all()

    # ── 餘額查詢 ──────────────────────────────────────────────────────────────
    if text in ("餘額", "查餘額", "balance"):
        if not cards:
            _reply(reply_token, "你還沒有設定卡片，請先在 App 新增。")
            return
        lines = []
        for c in cards:
            bal = f"${c.balance:,.0f}" if c.balance is not None else "未設定"
            lines.append(f"{_card_emoji(c.type)} {c.name}：{bal}")
        _reply(reply_token, "\n".join(lines))
        return

    # ── 悠遊卡餘額更新：「悠遊卡餘額 300」或「悠遊 300 設定」 ─────────────────
    easycard_re = re.match(r"^(?:悠遊卡?)\s*餘額\s+(\d+(?:\.\d+)?)$", text)
    if easycard_re:
        amount = float(easycard_re.group(1))
        easycard = next((c for c in cards if c.type == "easycard"), None)
        if easycard is None:
            _reply(reply_token, "找不到悠遊卡，請先在 App 新增。")
            return
        easycard.balance = amount
        db.commit()
        _reply(reply_token, f"✅ 悠遊卡餘額已更新為 ${amount:,.0f}")
        return

    # ── 記帳：「描述 金額」或「描述 金額 卡片關鍵字」 ────────────────────────
    tokens = text.split()
    amount: Optional[float] = None
    card_keyword: Optional[str] = None
    description: Optional[str] = None

    if len(tokens) >= 2:
        try:
            amount = float(tokens[-1])
            description = " ".join(tokens[:-1])
        except ValueError:
            if len(tokens) >= 3:
                try:
                    amount = float(tokens[-2])
                    card_keyword = tokens[-1]
                    description = " ".join(tokens[:-2])
                except ValueError:
                    pass

    if amount is None or description is None:
        _reply(
            reply_token,
            "看不懂指令～試試看：\n"
            "• 「茶葉蛋 10」\n"
            "• 「茶葉蛋 10 悠遊」（直接指定卡片）\n"
            "• 「餘額」查看各卡餘額\n"
            "• 「悠遊卡餘額 300」更新悠遊卡",
        )
        return

    if card_keyword:
        matched = _fuzzy_match_card(card_keyword, cards)
        if matched is None:
            _reply(reply_token, f"找不到「{card_keyword}」對應的卡片。\n傳「餘額」查看可用卡片清單。")
            return
        _record_expense(user, matched, amount, description, db, reply_token)
    else:
        # Quick Reply 讓使用者選卡
        items = [
            QuickReplyItem(
                action=PostbackAction(
                    label=f"{_card_emoji(c.type)}{c.name}" + (f"···{c.last_four}" if c.last_four else ""),
                    data=urllib.parse.urlencode({
                        "action": "expense",
                        "card_id": c.id,
                        "amount": amount,
                        "desc": description,
                    }),
                    display_text=c.name,
                )
            )
            for c in cards
        ] + [
            QuickReplyItem(
                action=PostbackAction(
                    label="💵現金",
                    data=urllib.parse.urlencode({
                        "action": "expense",
                        "card_id": "",
                        "amount": amount,
                        "desc": description,
                    }),
                    display_text="現金",
                )
            )
        ]
        _reply(
            reply_token,
            f"「{description}」${amount:,.0f}，要從哪扣？",
            QuickReply(items=items[:13]),
        )


def _handle_postback(data_str: str, line_user_id: str, reply_token: str, db: Session):
    params = dict(urllib.parse.parse_qsl(data_str))
    if params.get("action") != "expense":
        return

    user: Optional[models.User] = (
        db.query(models.User).filter(models.User.line_user_id == line_user_id).first()
    )
    if user is None:
        return

    try:
        amount = float(params.get("amount", 0))
    except ValueError:
        return

    description = params.get("desc", "")
    card_id_str = params.get("card_id", "")
    card: Optional[models.Card] = None
    if card_id_str:
        card = (
            db.query(models.Card)
            .filter(models.Card.id == int(card_id_str), models.Card.user_id == user.id)
            .first()
        )

    _record_expense(user, card, amount, description, db, reply_token)


def _handle_image(message_id: str, line_user_id: str, reply_token: str, db: Session):
    """使用者把銀行 LINE 通知的截圖轉傳過來：先存起來，實際的 OCR 辨識在 App 端用手機
    本機 OCR 做（跟「銀行通知記帳」畫面裡選相簿匯入是同一套流程），這裡只負責收圖。

    如果使用者剛傳過「班表」文字指令（roster_import_expected_until 還沒過期），
    這張圖片改存進 PendingRosterPhoto，走排班表匯入流程而不是銀行通知流程。"""
    user: Optional[models.User] = (
        db.query(models.User).filter(models.User.line_user_id == line_user_id).first()
    )
    if user is None:
        _reply(reply_token, "你還沒綁定帳號！\n請在 App 設定頁產生綁定碼，再傳「綁定 XXXXXX」給我。")
        return

    expecting_roster = (
        user.roster_import_expected_until is not None
        and user.roster_import_expected_until > datetime.now(timezone.utc)
    )
    # 不管有沒有過期，收到圖片就清掉旗標，避免第二張圖片也被誤判成班表。
    user.roster_import_expected_until = None

    with LineApiClient(_line_config) as client:
        image_bytes = MessagingApiBlob(client).get_message_content(message_id)

    if expecting_roster:
        photo = models.PendingRosterPhoto(
            user_id=user.id,
            image_data=bytes(image_bytes),
            content_type="image/jpeg",
        )
        db.add(photo)
        db.commit()
        _reply(reply_token, "📋 已收到班表照片！打開 YiWallet 的「班表匯入」確認辨識結果。")
        return

    shot = models.PendingBankScreenshot(
        user_id=user.id,
        image_data=bytes(image_bytes),
        content_type="image/jpeg",
    )
    db.add(shot)
    db.commit()

    _reply(reply_token, "📸 已收到截圖！打開 YiWallet 的「銀行通知記帳」就能看到待確認項目。")


def _record_expense(
    user: models.User,
    card: Optional[models.Card],
    amount: float,
    description: str,
    db: Session,
    reply_token: str,
):
    signed = -abs(amount)
    tx = models.Transaction(
        user_id=user.id,
        card_id=card.id if card else None,
        amount=signed,
        description=description,
        transaction_type="expense",
        category="other",
    )
    db.add(tx)
    if card and card.balance is not None:
        card.balance += signed
    db.commit()

    if card:
        bal_str = f"，剩 ${card.balance:,.0f}" if card.balance is not None else ""
        _reply(reply_token, f"✓ {_card_emoji(card.type)} {card.name} -${amount:,.0f}（{description}）{bal_str}")
    else:
        _reply(reply_token, f"✓ 💵 現金 -${amount:,.0f}（{description}）已記錄")
