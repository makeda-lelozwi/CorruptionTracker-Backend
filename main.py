from fastapi import FastAPI
import httpx
from selectolax.parser import HTMLParser

app = FastAPI()

def get_html(baseUrl):
    headers = {
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36"
    }
    resp = httpx.get(baseUrl, headers=headers)
    html = HTMLParser(resp.text)
    return html

def parse_page(html):
    links = html.css("table#newsArchive tbody tr")
    return links

    # parsed_paragraphs = {}

    # for index, paragraph in enumerate(paragraphs):
    #     parsed_paragraphs[index] = paragraph.text()
    #     print(paragraph.text())
    #     print("-------------------------------------------------------------------------")
        
    # print("loop finished")

def main():
    baseUrl = "https://www.parliament.gov.za/news"

    html = get_html(baseUrl)
    data = parse_page(html)
    
    for link in data:
        print(link.text())

if __name__ == "__main__":
    main()

# @app.get("/")
# def read_root():
#     return parsed_paragraphs

# @app.get("/items/{item_id}")
# def read_item(item_id: int, q: str = None):
#     return {"items": items[item_id], "query": q}

