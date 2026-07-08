from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

import models
from database import engine
from routers import (
    auth, bank_credit_settings, bank_notify, banks, cards, credit_accounts, einvoice,
    friends, income, jobs, line, payments, schedule, statements, transactions, users,
)

models.Base.metadata.create_all(bind=engine)

app = FastAPI(title="CampusLife API")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)
app.include_router(auth.router)
app.include_router(users.router)
app.include_router(friends.router)
app.include_router(jobs.router)
app.include_router(cards.router)
app.include_router(income.router)
app.include_router(line.router)
app.include_router(schedule.router)
app.include_router(transactions.router)
app.include_router(einvoice.router)
app.include_router(bank_notify.router)
app.include_router(banks.router)
app.include_router(credit_accounts.router)
app.include_router(statements.router)
app.include_router(payments.router)
app.include_router(bank_credit_settings.router)


@app.get("/")
def root():
    return {"status": "ok"}
