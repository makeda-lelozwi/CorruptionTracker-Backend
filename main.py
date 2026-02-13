from contextlib import asynccontextmanager
from fastapi import FastAPI, BackgroundTasks, Depends
import time
from fastapi.middleware.cors import CORSMiddleware
from datetime import datetime
import json
import models
from database import engine, SessionLocal
from sqlalchemy.orm import Session
from typing import Annotated
from utils import (
    DATA_FILE,
    get_month_html,
    save_articles,
    run_crawl,
)

models.Base.metadata.create_all(bind=engine)

def get_db():
  db = SessionLocal()
  try:
    yield db
  finally:
    db.close()

db_dependency = Annotated[Session, Depends(get_db)]

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifecycle events for the FastAPI app"""
    # Startup: run the crawler
    print("Triggering initial crawl on startup...")
    background_tasks = BackgroundTasks()
    background_tasks.add_task(run_crawl)
    await background_tasks()
    
    yield  # Server is running
    
    # Shutdown: cleanup if needed
    print("Shutting down...")

app = FastAPI(lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, replace with your frontend URL
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
def index(db: db_dependency):
    today = datetime.now().date()
 
    latest = db.query(models.NewsArticle).order_by(
        models.NewsArticle.published_on.desc()
    ).first()
 
    if latest and latest.published_on and today <= latest.published_on:
        return {
            "news": {
                "title": latest.title,
                "link": latest.source_url,
                "date": str(latest.published_on),
            }
        }

    now = datetime.now()
    html = get_month_html(now.month, now.year)

    if html:
        save_articles(db, html)

    db.commit()

    latest = db.query(models.NewsArticle).order_by(
        models.NewsArticle.published_on.desc()
    ).first()

    return {
        "news": {
            "title": latest.title,
            "link": latest.source_url,
            "date": str(latest.published_on),
        } if latest else None
    }
   
@app.get("/meetings")
def get_meetings():
    if not DATA_FILE.exists():
        return []
    try:
        return json.loads(DATA_FILE.read_text(encoding="utf-8"))
    except Exception:
        return []
    
@app.post("/seed")
def seed_news(db: db_dependency):
    now = datetime.now()
    if now.month >= 7:
        month_year_pairs = [(now.year, m) for m in range(now.month, 6, -1)]
    else:
        month_year_pairs = (
            [(now.year, m) for m in range(now.month, 0, -1)]
            + [(now.year - 1, m) for m in range(12, 6, -1)]
        )

    count = 0
    for year, month in month_year_pairs:
        html = get_month_html(month, year)
        if not html:
            continue

        count += save_articles(db, html)
        time.sleep(2)

    db.commit()
    return {"status": "seeded", "articles_added": count}

@app.post("/crawl")
def trigger_crawl(background_tasks: BackgroundTasks):
    # trigger a crawl in the background and return immediately
    background_tasks.add_task(run_crawl)
    return {"status": "crawl started"}
