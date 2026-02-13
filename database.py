import os
from dotenv import load_dotenv

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.ext.declarative import declarative_base

load_dotenv()

URL_DATABASE = os.getenv("URL_DATABASE")
if not URL_DATABASE:
    raise RuntimeError("URL_DATABASE environment variable is not set")

# Render uses "postgres://" but SQLAlchemy requires "postgresql://"
if URL_DATABASE.startswith("postgres://"):
    URL_DATABASE = URL_DATABASE.replace("postgres://", "postgresql://", 1)

engine = create_engine(URL_DATABASE)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()

