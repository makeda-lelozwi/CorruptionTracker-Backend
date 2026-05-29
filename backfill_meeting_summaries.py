import argparse
from pathlib import Path

import models
from database import SessionLocal, engine
from utils import DATA_FILE, load_meeting_summaries, save_meeting_summaries


DEFAULT_FILE = DATA_FILE


def backfill(file_path: Path, dry_run: bool) -> None:
    models.Base.metadata.create_all(bind=engine)

    meetings = load_meeting_summaries(file_path)

    db = SessionLocal()
    try:
        inserted, updated = save_meeting_summaries(db, meetings)

        if dry_run:
            db.rollback()
        else:
            db.commit()

        print(f"Loaded {len(meetings)} raw meeting records from {file_path.name}")
        print(f"Would insert: {inserted}" if dry_run else f"Inserted: {inserted}")
        print(f"Would update: {updated}" if dry_run else f"Updated: {updated}")
    finally:
        db.close()


def main():
    parser = argparse.ArgumentParser(
        description="Backfill meeting_summaries from the scraped ad-hoc-minutes JSON file."
    )
    parser.add_argument(
        "--file",
        default=str(DEFAULT_FILE),
        help="Path to the scraped meeting summaries file.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would be inserted or updated without changing the database.",
    )
    args = parser.parse_args()

    backfill(Path(args.file), args.dry_run)


if __name__ == "__main__":
    main()
