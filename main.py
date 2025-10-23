from fastapi import FastAPI
import httpx
from selectolax.parser import HTMLParser
from urllib.parse import urljoin
import time

app = FastAPI()

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

def get_month_html(month:int, year:int=2025) -> HTMLParser:
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
        html = HTMLParser(html_content)
        
        # Check if we got any articles
        rows = html.css("table#newsArchive tbody tr")
        print(f"  Found {len(rows)} articles")
        
        return html
    else:
        print(f"  No 'news-archive' key in response")
        return None

def parse_news_page(html):
    # Extract article links from the news archive table
    rows = html.css("table#newsArchive tbody tr")
    
    for row in rows:
        a_tag = row.css_first("a")
        text_cells = row.css("td")
        
        if a_tag and len(text_cells)>1:
            link = urljoin("https://www.parliament.gov.za/news", a_tag.attributes["href"])
            title = a_tag.text(strip=True)
            date = text_cells[1].text(strip=True)
            yield title, link,date


def get_page_html(baseUrl): 
    headers = { "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36" } 
    resp = httpx.get(baseUrl, headers=headers) 
    html = HTMLParser(resp.text) 
    return html

def parse_article(html):
    # Extract paragraphs from an article page
    paragraphs = html.css("div.small-12 p")

    parsed_paragraphs = {}

    for index, paragraph in enumerate(paragraphs):
        parsed_paragraphs[index] = paragraph.text()
        print(paragraph.text())
        print("-------------------------------------------------------------------------")
        
    print("loop finished")
  
@app.get("/")
def index():
    months = range(7,13)
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
   
