# Fetches metadata for one Getty asset id.
#
#   GettyClient.new.fetch("1234567890")
#   # => { title:, caption:, photographer:, ..., raw: {...}, fetched_via: "api" | "oembed" }
#
# Uses the v3 API when GETTY_API_KEY is set, otherwise oEmbed. Raises
# GettyClient::NotFound for unknown ids and GettyClient::Error for anything else
# so the job can decide what to retry.
class GettyClient
  Error    = Class.new(StandardError)
  NotFound = Class.new(Error)

  API_BASE    = "https://api.gettyimages.com/v3"
  OEMBED_BASE = "https://embed.gettyimages.com"
  MONTHS = Date::MONTHNAMES.compact.join("|")

  def self.infer_date(caption)
    return nil if caption.blank?

    # "September 4, 1957" / "4 September 1957" / "SEPTEMBER 4: " (dateline, year unknown)
    if (m = caption.match(/\b(#{MONTHS})\s+(\d{1,2})(?:st|nd|rd|th)?,?\s+(\d{4})\b/i))
        return Date.new(m[3].to_i, Date::MONTHNAMES.index(m[1].capitalize), m[2].to_i)
    end
    if (m = caption.match(/\b(\d{1,2})(st|nd|rd|th)?\s+(#{MONTHS})\s+(\d{4})\b/i))
        return Date.new(m[4].to_i, Date::MONTHNAMES.index(m[3].capitalize), m[1].to_i)
    end
    if (m = caption.match(/\b(1[89]\d\d|20\d\d)\b/))
      return Date.new(m[1].to_i, 1, 1) # year only; mark as approximate
    end
    nil
  rescue Date::Error
    nil
  end

  # Fields worth asking the API for. See developer.gettyimages.com for the full list.
  API_FIELDS = %w[
    id title caption artist collection_name date_created license_model
    max_dimensions keywords people display_sizes editorial_segments event_ids
  ].join(",")

  def initialize(api_key: ENV["GETTY_API_KEY"])
    @api_key = api_key.presence
  end

  def fetch(asset_id)
    @api_key ? fetch_api(asset_id) : fetch_oembed(asset_id)
  end

  private

  # --- v3 API ---------------------------------------------------------------

  def fetch_api(asset_id)
    resp = api_conn.get("images/#{asset_id}", fields: API_FIELDS)
    handle_status!(resp, asset_id)

    image = resp.body.fetch("images", []).first or raise NotFound, "asset #{asset_id} not in response"
    dims  = image["max_dimensions"] || {}
    thumb = (image["display_sizes"] || []).find { _1["name"] == "thumb" }

    {
      title:         image["title"],
      caption:       image["caption"],
      photographer:  image["artist"],
      credit:        image["artist"],
      collection:    image["collection_name"],
      date_created:  parse_date(image["date_created"]),
      license_model: image["license_model"],
      width:         dims["width"],
      height:        dims["height"],
      thumbnail_url: thumb&.dig("uri"),
      keywords:      Array(image["keywords"]).filter_map { _1["text"] },
      people:        Array(image["people"]),
      raw:           image,
      fetched_via:   "api"
    }
  end

  def api_conn
    @api_conn ||= Faraday.new(url: API_BASE) do |f|
      f.headers["Api-Key"] = @api_key
      f.headers["User-Agent"] = user_agent
      f.request  :retry, max: 3, interval: 1, backoff_factor: 2,
                 retry_statuses: [429, 500, 502, 503, 504]
      f.response :json
      f.options.timeout = 15
    end
  end

  # --- oEmbed ---------------------------------------------------------------

  def fetch_oembed(asset_id)
    resp = oembed_conn.get("oembed", url: "http://gty.im/#{asset_id}", caller: caller_domain)
    handle_status!(resp, asset_id)

    body = resp.body
    {
      title:         body["title"],
      caption:       body["caption"],
      photographer:  body["photographer"],
      credit:        body["photographer"],
      collection:    body["collection"],
      date_created:  self.class.infer_date(body["caption"]),
      license_model: nil,
      width:         body["width"],
      height:        body["height"],
      thumbnail_url: body["thumbnail_url"],
      keywords:      [],
      people:        [],
      raw:           body,
      fetched_via:   "oembed"
    }
  end

  def oembed_conn
    @oembed_conn ||= Faraday.new(url: OEMBED_BASE) do |f|
      f.headers["User-Agent"] = user_agent
      f.request  :retry, max: 3, interval: 2, backoff_factor: 2,
                 retry_statuses: [429, 500, 502, 503, 504]
      f.response :json, content_type: /\bjson$/
      f.options.timeout = 15
    end
  end

  # --- shared ---------------------------------------------------------------

  def handle_status!(resp, asset_id)
    case resp.status
    when 200 then nil
    when 404 then raise NotFound, "asset #{asset_id} not available via oEmbed (not embeddable or doesn't exist)"
    when 401, 403 then raise Error, "auth error (#{resp.status}) — check GETTY_API_KEY"
    else raise Error, "Getty returned #{resp.status} for #{asset_id}"
    end
  end

  def parse_date(value)
    Date.parse(value) if value.present?
  rescue Date::Error
    nil
  end

  def user_agent
    "getty-meta/#{Rails.application.class.module_parent_name} (+#{caller_domain})"
  end

  def caller_domain
    ENV.fetch("APP_HOST", "localhost")
  end
end
