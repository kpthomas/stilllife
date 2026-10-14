require "csv"

class AssetCsv
  Column = Data.define(:header, :value)

  COLUMNS = [
    Column.new("Thumbnail", ->(a) { %(=IMAGE("#{a.thumbnail_url}")) if a.thumbnail_url.present? }),
    Column.new("Title / Description", ->(a) { a.title || a.caption }),
    Column.new("Media Type", ->(_) { "Still" }),
    Column.new("My Filename", ->(_) { "" }),
    Column.new("Original Filename", ->(_) { "" }),
    Column.new("Date of Original", ->(a) { a.date_created&.iso8601 || a.date_text }),
    Column.new("Year", ->(a) { a.date_created&.year || a.date_text }),
    Column.new("Thumbnail URL", :thumbnail_url)
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
