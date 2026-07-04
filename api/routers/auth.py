import os

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

GOOGLE_CLIENT_ID = os.getenv("GOOGLE_CLIENT_ID")


def _verify_google_id_token(id_token: str) -> dict:
    try:
        return google_id_token.verify_oauth2_token(
            id_token, google_requests.Request(), GOOGLE_CLIENT_ID,
        )
    except ValueError:
        raise HTTPException(status_code=401, detail="Google 驗證失敗")


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
