from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import or_
from sqlalchemy.orm import Session

import models
import schemas
from auth import get_current_user
from database import get_db

router = APIRouter(prefix="/friends", tags=["friends"])


@router.get("", response_model=list[schemas.FriendshipRead])
def list_friendships(
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    rows = (
        db.query(models.Friendship)
        .filter(
            or_(
                models.Friendship.user_id == current_user.id,
                models.Friendship.friend_id == current_user.id,
            )
        )
        .all()
    )

    results = []
    for row in rows:
        is_incoming = row.friend_id == current_user.id
        other_id = row.user_id if is_incoming else row.friend_id
        other_user = db.query(models.User).filter(models.User.id == other_id).first()
        results.append(
            schemas.FriendshipRead(id=row.id, status=row.status, friend=other_user, incoming=is_incoming)
        )
    return results


@router.post("/request", response_model=schemas.FriendshipRead)
def request_friend(
    payload: schemas.FriendRequestCreate,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    target = db.query(models.User).filter(models.User.email == payload.email).first()
    if target is None:
        raise HTTPException(status_code=404, detail="找不到這個 email 的使用者")
    if target.id == current_user.id:
        raise HTTPException(status_code=400, detail="不能加自己好友")

    existing = (
        db.query(models.Friendship)
        .filter(
            or_(
                (models.Friendship.user_id == current_user.id) & (models.Friendship.friend_id == target.id),
                (models.Friendship.user_id == target.id) & (models.Friendship.friend_id == current_user.id),
            )
        )
        .first()
    )
    if existing:
        raise HTTPException(status_code=400, detail="已經是好友或邀請已送出")

    friendship = models.Friendship(user_id=current_user.id, friend_id=target.id, status="pending")
    db.add(friendship)
    db.commit()
    db.refresh(friendship)
    return schemas.FriendshipRead(id=friendship.id, status=friendship.status, friend=target, incoming=False)


@router.post("/{friendship_id}/accept", response_model=schemas.FriendshipRead)
def accept_friend(
    friendship_id: int,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    friendship = (
        db.query(models.Friendship)
        .filter(models.Friendship.id == friendship_id, models.Friendship.friend_id == current_user.id)
        .first()
    )
    if friendship is None:
        raise HTTPException(status_code=404, detail="找不到這個邀請")

    friendship.status = "accepted"
    db.commit()
    db.refresh(friendship)
    requester = db.query(models.User).filter(models.User.id == friendship.user_id).first()
    return schemas.FriendshipRead(id=friendship.id, status=friendship.status, friend=requester, incoming=True)
