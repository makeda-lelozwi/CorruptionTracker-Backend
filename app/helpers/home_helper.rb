module HomeHelper
  def testimony_day(testimony)
    testimony.fetch("title").to_s[/Day\s+\d+/i] || testimony.fetch("title")
  end

  def testimony_short_date(testimony)
    Date.parse(testimony.fetch("date").to_s).strftime("%-d %b %Y")
  rescue Date::Error
    testimony["date"]
  end

  def testimony_heading(testimony)
    day = testimony_day(testimony)
    date = Date.parse(testimony.fetch("date").to_s).strftime("%-d %B %Y")
    [ date, day ].compact.join(", ")
  rescue Date::Error
    [ testimony["date"], day ].compact.join(", ")
  end
end
