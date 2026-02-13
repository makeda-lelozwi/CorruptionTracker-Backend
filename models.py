from sqlalchemy import (
    Column,
    Date,
    DateTime,
    ForeignKey,
    Integer,
    String,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import relationship

from database import Base

class NewsArticle(Base):
    __tablename__ = "news_articles"
    __table_args__ = (
        UniqueConstraint("source_url", name="uq_news_articles_source_url"),
    )

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String(500), nullable=False, index=True)
    published_on = Column(Date, nullable=True, index=True)
    source_url = Column(String(1200), nullable=False)
    source_name = Column(String(100), nullable=False, default="parliament.gov.za")
    summary = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
    updated_at = Column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )
   


class MeetingSummary(Base):
    __tablename__ = "meeting_summaries"
    __table_args__ = (
        UniqueConstraint("video_link", name="uq_meeting_summaries_video_link"),
    )

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String(500), nullable=False, index=True)
    meeting_date = Column(Date, nullable=True, index=True)
    raw_date = Column(String(64), nullable=True)
    video_link = Column(String(1200), nullable=False)
    source_name = Column(String(100), nullable=False, default="pmg.org.za")
    summary = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
    updated_at = Column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )
   
