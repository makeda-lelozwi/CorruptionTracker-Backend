import scrapy
from itemloaders.processors import TakeFirst, MapCompose
from w3lib.html import remove_tags
from w3lib.html import replace_entities
from parsel import Selector

def extract_href(value):
   """Extracts the href attribute from an <a> tag string."""
   sel = Selector(text=value)
   href = sel.css("a::attr(href)").get()
   if href:
      return replace_entities(href.strip())
   return value   

def join_summary_paragraphs(value):
    """
    Takes the HTML string for the entire div.meeting-summary,
    selects all <p> tags starting from the third one,
    and joins them with <br> tags between paragraphs.
    """
    sel = Selector(text=value)
    paragraphs = sel.css('div.meeting-summary p:nth-of-type(n+3)').getall()
    return "<br>".join(paragraphs) if paragraphs else value

class ScraperItem(scrapy.Item):
   title = scrapy.Field(
      input_processor=MapCompose(remove_tags), 
      output_processor=TakeFirst())
   date = scrapy.Field(
      input_processor=MapCompose(remove_tags), 
      output_processor=TakeFirst()) 
   video_link = scrapy.Field(
      input_processor=MapCompose(extract_href), 
      output_processor=TakeFirst())
   summary = scrapy.Field(
      input_processor=MapCompose(join_summary_paragraphs,remove_tags), 
      output_processor=TakeFirst())
   # full_minutes = scrapy.Field(input_processor=MapCompose(remove_tags), output_processor=TakeFirst())

