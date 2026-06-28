from fastapi import FastAPI

import models
from database import engine
from routers import schedule

models.Base.metadata.create_all(bind=engine)

app = FastAPI(title="CampusLife API")
app.include_router(schedule.router)


@app.get("/")
def root():
    return {"status": "ok"}
