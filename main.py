from contextlib import asynccontextmanager
from fastapi import FastAPI, BackgroundTasks
import httpx
from bs4 import BeautifulSoup
from urllib.parse import urljoin
import time
from fastapi.middleware.cors import CORSMiddleware
from datetime import datetime
import json
import subprocess
from pathlib import Path

app = FastAPI()
DATA_FILE = Path(__file__).parent / "ad-hoc-minutes.json"

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, replace with your frontend URL
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

def run_crawl():
    """
    Runs the Scrapy spider as a subprocess and writes output to DATA_FILE.
    Requires the project root to be the current working directory (where scrapy.cfg lives).
    """
    print("Starting crawl...")
    project_dir = Path(__file__).parent / "scraper"
    output_file = Path(__file__).parent / "ad-hoc-minutes.json"
    try:
        res = subprocess.run(
            ["scrapy", "crawl", "meetings", "-o", str(output_file)],
            check=True,
            cwd=str(project_dir),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        print("crawl stdout:", res.stdout)
        print("crawl stderr:", res.stderr)
        print("crawl completed successfully")
    except subprocess.CalledProcessError as e:
        print("crawl failed:", e.returncode)
        print("stdout:", e.stdout)
        print("stderr:", e.stderr)


BASE_URL = "https://www.parliament.gov.za/news"
HEADERS = {
    "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36",
    "Referer": BASE_URL,
    "X-Requested-With": "XMLHttpRequest",
    "Content-Type": "application/x-www-form-urlencoded",
    "X-OCTOBER-REQUEST-HANDLER": "onDatechange",  # Critical!
    "X-OCTOBER-REQUEST-PARTIALS": "news-archive",  # Critical!
}
FILTER_KEYWORDS = [
    "Gen Mkhwanazi", "Disband", "Political Killings",
    "Task Team", "Police Minister", "Lieutenant",
    "Commissioner", "Allegations", "Ad Hoc Committee"
]

def get_month_html(month:int, year:int=2025) -> BeautifulSoup | None:
    # Fetch HTML for a specific month/year (POST req)
    print(f"Getting news for {month}")
    payload = {"newDate": f"{month} {year}"}
    resp = httpx.post(BASE_URL, headers=HEADERS, data=payload,  follow_redirects=True)
    resp.raise_for_status()

  
    json_resp = resp.json()
    
    # return HTMLParser(resp.text)

     # Extract HTML from the 'news-archive' key
    if 'news-archive' in json_resp:
        html_content = json_resp['news-archive']
        soup = BeautifulSoup(html_content, 'html.parser')
      
        # Check if we got any articles
        rows = soup.select("table#newsArchive tbody tr")
        print(f"  Found {len(rows)} articles")
        
        return soup
    else:
        print(f"  No 'news-archive' key in response")
        return None

def parse_news_page(soup: BeautifulSoup):
    # Extract article links from the news archive table
    rows = soup.select("table#newsArchive tbody tr")
    
    for row in rows:
        a_tag = row.select_one("a")
        text_cells = row.find_all("td")
        
        if a_tag and len(text_cells)>1:
            href = a_tag.get("href", "")
            link = urljoin(BASE_URL, href)
            title = a_tag.get_text(strip=True)
            date = text_cells[1].get_text(strip=True)
            yield title, link, date


def get_page_html(baseUrl: str) -> BeautifulSoup:
    headers = { "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36" } 
    resp = httpx.get(baseUrl, headers=headers) 
    soup = BeautifulSoup(resp.text, "html.parser")
    return soup

def parse_article(soup: BeautifulSoup):
    # Extract paragraphs from an article page
    paragraphs = soup.select("div.small-12 p")

    parsed_paragraphs = {}

    for index, paragraph in enumerate(paragraphs):
        parsed_paragraphs[index] = paragraph.text()
        print(paragraph.text())
        print("-------------------------------------------------------------------------")
        
    print("loop finished")

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
def index():
    now = datetime.now()
    # Iterate from the current month down to July (7). 
    # If you want to go all the way to January, change the 6 to 0.
    months = range(now.month, 6, -1)
    news_results = []
    for month in months:
        html = get_month_html(month)

        if not html:
            continue

        for title, link, date in parse_news_page(html):
            if any(keyword.lower() in title.lower() for keyword in FILTER_KEYWORDS):
                news_results.append({
                "title": title,
                "link": link,
                "date": date
                })
        time.sleep(2)
    return {"news": news_results}
   
@app.get("/meetings")
def get_meetings():
    if not DATA_FILE.exists():
        return []
    try:
        return json.loads(DATA_FILE.read_text(encoding="utf-8"))
    except Exception:
        return []
    
@app.post("/crawl")
def trigger_crawl(background_tasks: BackgroundTasks):
    # trigger a crawl in the background and return immediately
    background_tasks.add_task(run_crawl)
    return {"status": "crawl started"}
    