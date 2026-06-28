from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

import models
from database import engine
from routers import schedule

models.Base.metadata.create_all(bind=engine)

app = FastAPI(title="CampusLife API")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)
app.include_router(schedule.router)


@app.get("/")
def root():
    return {"status": "ok"}
