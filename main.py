from contextlib import asynccontextmanager
from fastapi import FastAPI, BackgroundTasks, Depends
import time
from fastapi.middleware.cors import CORSMiddleware
from datetime import datetime
import models
from database import engine, SessionLocal
from sqlalchemy.orm import Session
from typing import Annotated
from utils import (
    DATA_FILE,
    get_month_html,
    save_articles,
    run_crawl,
    sync_meeting_summaries,
)

models.Base.metadata.create_all(bind=engine)

def get_db():
  db = SessionLocal()
  try:
    yield db
  finally:
    db.close()

db_dependency = Annotated[Session, Depends(get_db)]


def serialize_meeting_summary(meeting: models.MeetingSummary) -> dict:
    return {
        "title": meeting.title,
        "date": meeting.raw_date,
        "video_link": meeting.video_link,
        "summary": meeting.summary,
    }


def ensure_meeting_summaries(db: Session) -> None:
    if db.query(models.MeetingSummary).count() > 0 or not DATA_FILE.exists():
        return

    inserted, updated = sync_meeting_summaries(db)
    db.commit()
    print(
        f"Seeded meeting summaries from file. Inserted: {inserted}, Updated: {updated}"
    )


def refresh_meeting_summaries():
    run_crawl()

    db = SessionLocal()
    try:
        inserted, updated = sync_meeting_summaries(db)
        db.commit()
        print(
            f"Synced meeting summaries after crawl. Inserted: {inserted}, Updated: {updated}"
        )
    except Exception as exc:
        db.rollback()
        print(f"Meeting summary sync failed: {exc}")
    finally:
        db.close()

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifecycle events for the FastAPI app"""
    # Startup: seed news if DB is empty
    db = SessionLocal()
    try:
        count = db.query(models.NewsArticle).count()
        if count == 0:
            print("No news articles found. Seeding...")
            now = datetime.now()
            if now.month >= 7:
                month_year_pairs = [(now.year, m) for m in range(now.month, 6, -1)]
            else:
                month_year_pairs = (
                    [(now.year, m) for m in range(now.month, 0, -1)]
                    + [(now.year - 1, m) for m in range(12, 6, -1)]
                )
 
            added = 0
            for year, month in month_year_pairs:
                html = get_month_html(month, year)
                if not html:
                    continue
                added += save_articles(db, html)
                time.sleep(2)
 
            db.commit()
            print(f"Seeded {added} news articles.")
        else:
            print(f"DB already has {count} news articles. Skipping seed.")

        meeting_count = db.query(models.MeetingSummary).count()
        if meeting_count == 0:
            inserted, updated = sync_meeting_summaries(db)
            db.commit()
            print(
                f"Seeded {inserted} meeting summaries and updated {updated} existing rows."
            )
        else:
            print(f"DB already has {meeting_count} meeting summaries. Skipping seed.")
    finally:
        db.close()

    # Startup: run the crawler
    print("Triggering initial crawl on startup...")
    background_tasks = BackgroundTasks()
    background_tasks.add_task(refresh_meeting_summaries)
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
def get_meetings(db: db_dependency):
    ensure_meeting_summaries(db)

    meetings = db.query(models.MeetingSummary).order_by(
        models.MeetingSummary.meeting_date.desc(),
        models.MeetingSummary.id.desc(),
    ).all()

    return [serialize_meeting_summary(meeting) for meeting in meetings]
    
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
    background_tasks.add_task(refresh_meeting_summaries)
    return {"status": "crawl started"}
