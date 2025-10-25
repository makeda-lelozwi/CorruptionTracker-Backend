import scrapy 
from scrapy.spiders import CrawlSpider, Rule
from scrapy.linkextractors import LinkExtractor
from ..items import ScraperItem
from scrapy.loader import ItemLoader

class MeetingsSpider(CrawlSpider):
    name = "meetings"
    start_urls = [
       "https://pmg.org.za/committee/391/?filter=2025",
       "https://pmg.org.za/committee-meeting/41407/"
    ]

    rules = (
        Rule(LinkExtractor(allow=r'committee/391/\?filter=\d{4}'), follow=True),
        Rule(LinkExtractor(allow=r'committee-meeting/\d+/'), callback='parse_meeting', follow=True),
    )

    def parse_meeting(self, response):  
        l = ItemLoader(item = ScraperItem(), response=response)

        l.add_css('title', "header.committee-header h1")
        l.add_css('date', "h5.date")
        l.add_css('video_link', "div.meeting-summary p a")
        l.add_css('summary', "div.meeting-summary ")
        # l.add_css('full_minutes', "div.full-minutes p")

        return l.load_item()

