import os
import random
import smtplib
import string
from datetime import datetime, timedelta, timezone
from email.mime.text import MIMEText

import requests as http_requests
from fastapi import APIRouter, Depends, HTTPException
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token as google_id_token
from sqlalchemy.orm import Session

import models
import schemas
from auth import create_access_token, get_current_user, hash_password, verify_password
from database import get_db

router = APIRouter(prefix="/auth", tags=["auth"])

GOOGLE_CLIENT_ID = os.getenv("GOOGLE_CLIENT_ID")  # Web client（後端 / Web 版 App 用）
GOOGLE_IOS_CLIENT_ID = os.getenv("GOOGLE_IOS_CLIENT_ID")
GOOGLE_ANDROID_CLIENT_ID = os.getenv("GOOGLE_ANDROID_CLIENT_ID")

_SMTP_HOST = os.getenv("SMTP_HOST")
_SMTP_PORT = int(os.getenv("SMTP_PORT", "465"))
_SMTP_USER = os.getenv("SMTP_USER")
_SMTP_PASSWORD = os.getenv("SMTP_PASSWORD")
_SMTP_FROM = os.getenv("SMTP_FROM", _SMTP_USER or "")


def _send_reset_email(to_email: str, code: str):
    if not (_SMTP_HOST and _SMTP_USER and _SMTP_PASSWORD):
        raise HTTPException(status_code=503, detail="伺服器尚未設定寄信服務")
    msg = MIMEText(f"你的 YiWallet 重設密碼驗證碼是：{code}\n10 分鐘內有效，如果不是你本人操作請忽略這封信。")
    msg["Subject"] = "YiWallet 重設密碼"
    msg["From"] = _SMTP_FROM
    msg["To"] = to_email
    with smtplib.SMTP_SSL(_SMTP_HOST, _SMTP_PORT) as server:
        server.login(_SMTP_USER, _SMTP_PASSWORD)
        server.sendmail(_SMTP_FROM, [to_email], msg.as_string())

# 每個平台（Web / iOS / Android）原生 SDK 簽發的 idToken，aud（受眾）欄位
# 會是「該平台自己的」OAuth Client ID，不是統一的 Web Client ID，
# 所以驗證時要接受這一整組合法的 Client ID，不能只認一個。
_ALLOWED_GOOGLE_AUDIENCES = {
    cid for cid in (GOOGLE_CLIENT_ID, GOOGLE_IOS_CLIENT_ID, GOOGLE_ANDROID_CLIENT_ID) if cid
}


def _verify_google_id_token(id_token: str) -> dict:
    try:
        idinfo = google_id_token.verify_oauth2_token(id_token, google_requests.Request())
    except ValueError:
        raise HTTPException(status_code=401, detail="Google 驗證失敗")
    if idinfo.get("aud") not in _ALLOWED_GOOGLE_AUDIENCES:
        raise HTTPException(status_code=401, detail="Google 驗證失敗（不受信任的用戶端）")
    return idinfo


def _verify_google_access_token(access_token: str) -> dict:
    # Flutter Web 的 google_sign_in 只會拿到 accessToken（拿不到 idToken），
    # 改成用 accessToken 打 Google 的 userinfo endpoint 換取使用者資料，
    # 順便驗證這個 token 是不是真的有效。
    response = http_requests.get(
        "https://www.googleapis.com/oauth2/v3/userinfo",
        headers={"Authorization": f"Bearer {access_token}"},
        timeout=10,
    )
    if response.status_code != 200:
        raise HTTPException(status_code=401, detail="Google 驗證失敗")
    data = response.json()
    return {
        "sub": data["sub"],
        "email": data.get("email"),
        "name": data.get("name"),
        "picture": data.get("picture"),
    }


@router.post("/register", response_model=schemas.Token)
def register(payload: schemas.UserCreate, db: Session = Depends(get_db)):
    if db.query(models.User).filter(models.User.email == payload.email).first():
        raise HTTPException(status_code=400, detail="這個 email 已經註冊過了")

    user = models.User(
        email=payload.email,
        password_hash=hash_password(payload.password),
        display_name=payload.display_name,
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    token = create_access_token(user.id)
    return schemas.Token(access_token=token, user=user)


@router.post("/login", response_model=schemas.Token)
def login(payload: schemas.UserLogin, db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.email == payload.email).first()
    if user is None or not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=401, detail="email 或密碼錯誤")

    token = create_access_token(user.id)
    return schemas.Token(access_token=token, user=user)


@router.post("/google", response_model=schemas.Token)
def google_login(payload: schemas.GoogleAuthPayload, db: Session = Depends(get_db)):
    if payload.id_token:
        idinfo = _verify_google_id_token(payload.id_token)
    elif payload.access_token:
        idinfo = _verify_google_access_token(payload.access_token)
    else:
        raise HTTPException(status_code=400, detail="缺少 Google 驗證資訊")

    google_sub = idinfo["sub"]
    email = idinfo.get("email")
    picture = idinfo.get("picture")
    name = idinfo.get("name") or (email.split("@")[0] if email else "使用者")

    user = db.query(models.User).filter(models.User.google_id == google_sub).first()
    if user is None and email:
        user = db.query(models.User).filter(models.User.email == email).first()

    if user is None:
        if not email:
            raise HTTPException(status_code=400, detail="這個 Google 帳號沒有可用的 email")
        user = models.User(
            email=email,
            display_name=name,
            picture=picture,
            google_id=google_sub,
        )
        db.add(user)
    else:
        if user.google_id is None:
            user.google_id = google_sub
        if not user.picture and picture:
            user.picture = picture

    db.commit()
    db.refresh(user)

    token = create_access_token(user.id)
    return schemas.Token(access_token=token, user=user)


@router.post("/forgot-password")
def forgot_password(payload: schemas.ForgotPasswordRequest, db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.email == payload.email).first()
    if user is not None:
        code = "".join(random.choices(string.digits, k=6))
        user.reset_code = code
        user.reset_code_expires_at = datetime.now(timezone.utc) + timedelta(minutes=10)
        db.commit()
        _send_reset_email(user.email, code)
    # 不管帳號存不存在都回同樣的訊息，避免被拿來探測哪些 email 有註冊
    return {"status": "ok"}


@router.post("/reset-password")
def reset_password(payload: schemas.ResetPasswordRequest, db: Session = Depends(get_db)):
    now = datetime.now(timezone.utc)
    user = (
        db.query(models.User)
        .filter(
            models.User.email == payload.email,
            models.User.reset_code == payload.code,
            models.User.reset_code_expires_at > now,
        )
        .first()
    )
    if user is None:
        raise HTTPException(status_code=400, detail="驗證碼錯誤或已過期")

    user.password_hash = hash_password(payload.new_password)
    user.reset_code = None
    user.reset_code_expires_at = None
    db.commit()
    return {"status": "ok"}


@router.get("/me", response_model=schemas.UserRead)
def me(current_user: models.User = Depends(get_current_user)):
    return current_user


@router.patch("/me", response_model=schemas.UserRead)
def update_me(
    payload: schemas.UpdateProfile,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if payload.display_name is not None:
        current_user.display_name = payload.display_name
    db.commit()
    db.refresh(current_user)
    return current_user
