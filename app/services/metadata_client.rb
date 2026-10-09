# Picks the right client for a URL. Add a new source by appending to SOURCES.
module MetadataClient
  SOURCES = {
    "getty" => {
      match:   ->(url) { url.match?(/gettyimages\.com|gty\.im/i) },
      extract: ->(url) { GettyAsset.extract_asset_id(url) },
      client:  -> { GettyClient.new }
    },
    "loc" => {
      match:   ->(url) { url.match?(/\bloc\.gov/i) },
      # https://www.loc.gov/item/98500455/  →  98500455
      # https://www.loc.gov/pictures/item/98500455/  →  98500455
      # https://www.loc.gov/resource/cph.3c23828/  →  cph.3c23828 (resource ids work on /item/ too)
      extract: ->(url) { url[%r{/(?:item|resource)/([^/?#]+)}, 1] },
      client:  -> { LocClient.new }
    }
  }.freeze

  # Returns [source, asset_id] or nil if nothing matches.
  def self.identify(url)
    SOURCES.each do |source, spec|
      next unless spec[:match].call(url)
      id = spec[:extract].call(url)
      return [source, id] if id
    end
    nil
  end

  def self.for(source)
    SOURCES.fetch(source)[:client].call
  end
end
