# Fetches metadata for one Library of Congress item via the public loc.gov JSON
# API (no key needed): https://www.loc.gov/item/{id}/?fo=json&at=item,resources
#
# Returns the same normalized hash shape GettyClient does, so the job and views
# don't care which source an asset came from.
class LocClient
  Error    = Class.new(StandardError)
  NotFound = Class.new(Error)

  BASE = "https://www.loc.gov"

  def fetch(item_id)
    resp = conn.get("item/#{item_id}/", fo: "json", at: "item,resources")
    case resp.status
    when 200 then nil
    when 404 then raise NotFound, "LoC item #{item_id} not found"
    else raise Error, "loc.gov returned #{resp.status} for #{item_id}"
    end

    item      = resp.body["item"] or raise NotFound, "no item in response for #{item_id}"
    resources = Array(resp.body["resources"])

    {
      title:         item["title"],
      caption:       [Array(item["notes"]).join(" "), item["description"]&.join(" ")].reject(&:blank?).join("\n\n").presence,
      photographer:  Array(item["contributor_names"] || item["contributors"]).join("; ").presence,
      credit:        credit_line(item),
      collection:    Array(item["source_collection"] || item["partof"]).map { _1.is_a?(Hash) ? _1["title"] : _1 }.join("; ").presence,
      date_created:  parse_date(item["date"]),
      date_text:     item["date"] || Array(item["created_published"]).first,
      license_model: nil,
      rights:        Array(item["rights_advisory"] || item["rights"]).join(" ").presence,
      width:         largest_image(resources)&.dig("width"),
      height:        largest_image(resources)&.dig("height"),
      thumbnail_url: Array(item["image_url"])[-2] || Array(item["image_url"]).last,
      keywords:      Array(item["subject_headings"] || item["subjects"]),
      people:        [], # LoC puts people under subject headings; leave in keywords
      source_id:     Array(item["reproduction_number"]).first,
      raw:           resp.body,
      fetched_via:   "loc_json"
    }
  end

  private

  def conn
    @conn ||= Faraday.new(url: BASE) do |f|
      f.headers["User-Agent"] = "getty-meta (+#{ENV.fetch('APP_HOST', 'localhost')})"
      f.request  :retry, max: 3, interval: 2, backoff_factor: 2,
                 retry_statuses: [429, 500, 502, 503, 504]
      f.response :json, content_type: /\bjson$/
      f.options.timeout = 20
    end
  end

  def credit_line(item)
    parts = ["Library of Congress"]
    parts << Array(item["repository"]).first if item["repository"].present?
    parts << Array(item["reproduction_number"]).first if item["reproduction_number"].present?
    parts.compact.join(", ")
  end

  # LoC dates are strings like "1957", "1910/1920", "[between 1900 and 1910]",
  # "1957-09-04", or "circa 1950". Keep the original in date_text; here we try
  # for a Date and give up gracefully.
  def parse_date(value)
    return nil if value.blank?
    s = value.to_s
    if (m = s.match(/\b(\d{4})-(\d{2})-(\d{2})\b/))
      Date.new(m[1].to_i, m[2].to_i, m[3].to_i)
    elsif (m = s.match(/\b(\d{4})-(\d{2})\b/))
      Date.new(m[1].to_i, m[2].to_i, 1)
    elsif (m = s.match(/\b(1[5-9]\d\d|20\d\d)\b/))
      Date.new(m[1].to_i, 1, 1) # year only or first year of a range
    end
  rescue Date::Error
    nil
  end

  def largest_image(resources)
    files = resources.flat_map { |r| Array(r["files"]).flatten }
    files.select { _1["mimetype"].to_s.start_with?("image/") }
         .max_by { _1["width"].to_i }
  end
end
