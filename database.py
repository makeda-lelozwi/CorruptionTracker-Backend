import os
import re
from urllib.parse import quote_plus
from dotenv import load_dotenv

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.engine import make_url

load_dotenv()

URL_DATABASE = os.getenv("URL_DATABASE") or os.getenv("DATABASE_URL")
if not URL_DATABASE:
    raise RuntimeError("URL_DATABASE or DATABASE_URL environment variable is not set")

# Render uses "postgres://" but SQLAlchemy requires "postgresql://"
if URL_DATABASE.startswith("postgres://"):
    URL_DATABASE = URL_DATABASE.replace("postgres://", "postgresql://", 1)

# Re-encode credentials so special chars (like @ or !) in the password
# don't break URL parsing.  We match: scheme://user:password@host...
# The password is everything between the first ":" after "//" and the
# LAST "@" before the host (greedy match handles @ inside passwords).
_m = re.match(r"^(postgresql(?:\+\w+)?://)([^:]+):(.+)@([^@]+)$", URL_DATABASE)
if _m:
    _scheme, _user, _password, _rest = _m.groups()
    URL_DATABASE = f"{_scheme}{quote_plus(_user)}:{quote_plus(_password)}@{_rest}"

url = make_url(URL_DATABASE)

# Amazon RDS PostgreSQL connections typically expect TLS.
if (
    url.drivername.startswith("postgresql")
    and url.host
    and "rds.amazonaws.com" in url.host
    and "sslmode" not in url.query
):
    url = url.update_query_dict({"sslmode": os.getenv("DB_SSL_MODE", "require")})

engine = create_engine(url, pool_pre_ping=True)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()
