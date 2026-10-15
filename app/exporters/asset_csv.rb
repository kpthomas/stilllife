require "csv"

class AssetCsv
  Column = Data.define(:header, :value)
  OK = "OK"
  OUT_OF_RANGE = "OUT OF RANGE"

  COLUMNS = [
    Column.new("ID", ->(_) { "" }),
    Column.new("Thumbnail", ->(a) { %(=IMAGE("#{a.thumbnail_url}")) if a.thumbnail_url.present? }),
    Column.new("Title / Description", ->(a) { a.title || a.caption }),
    Column.new("Media Type", ->(_) { "Still" }),
    Column.new("My Filename", ->(_) { "" }),
    Column.new("Original Filename", ->(_) { "" }),
    Column.new("Date of Original", ->(a) { a.date_created&.iso8601 || a.date_text }),
    Column.new("Year", ->(a) { a.date_created&.year || a.date_text }),
    Column.new("Range Check", ->(a) { a.date_created&.year&.between?(1950,1959) ? OK : OUT_OF_RANGE }),
    Column.new("Date Basis", ->(_) { "" }),
    Column.new("Creator", :photographer),
    Column.new("Repository", ->(a) {
      case a.source
      when "loc" then "Library of Congress"
      else a.source.strip.humanize
      end
    }),

    Column.new("Collection / Series", :collection),
    Column.new("Identifier", ->(a) {
      case a.source
      when "loc"   then a.source_id.to_s[/\A[^\s,(;]+/]
      when "getty" then a.asset_id
      end
    }),
    Column.new("Thumbnail URL", :thumbnail_url),
    Column.new("Permalink (record page)", :source_url),
    Column.new("Rights Statement (verbatim)", :rights),
    Column.new("Rights Basis", ->(a) {
      case a.rights.to_s.strip
      when /\Ano known restrictions/i then "No known restrictions (per repository)"
      when /\Arights managed/i        then "IN COPYRIGHT - license required"
      end
    }),
    Column.new("Notes", ->(_) { "" }),
  ].freeze

  def self.headers = COLUMNS.map(&:header)

  def self.row(asset)
    COLUMNS.map do |col|
      col.value.respond_to?(:call) ? col.value.call(asset) : asset.public_send(col.value)
    end
  end

  def self.generate(scope = GettyAsset.done) 
    CSV.generate do |csv|
      csv << headers
      scope.find_each { |asset| csv << row(asset) }
    end
  end
end
