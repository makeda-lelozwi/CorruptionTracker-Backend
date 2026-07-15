module HomeHelper
  def testimony_heading(testimony)
    day = testimony.fetch("title").to_s[/Day\s+\d+/i]
    date = Date.parse(testimony.fetch("date").to_s).strftime("%-d %B %Y")
    [ date, day ].compact.join(", ")
  rescue Date::Error
    [ testimony["date"], day ].compact.join(", ")
  end
end
