import scrapy 
from scrapy.spiders import CrawlSpider, Rule
from scrapy.linkextractors import LinkExtractor

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
        yield {
                'title': response.css("header.committee-header h1::text").get(),
                'date': response.css("h5.date::text").get(),
                'video_link': response.css("div.meeting-summary p a::attr(href)").get(),
                'summary': response.css("div.meeting-summary p::text").get(),
                'full_minutes': response.css("div.full-minutes p::text").get(),
        }

