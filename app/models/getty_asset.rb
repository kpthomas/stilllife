require "csv"

class GettyAsset < ApplicationRecord
  STATUSES = %w[pending done failed not_found].freeze

  # Matches the asset id in every Getty URL shape we've seen:
  #   gettyimages.com/detail/.../1234567890
  #   gettyimages.com/detail/news-photo/slug-news-photo/1234567890?adppopup=true
  #   media.gettyimages.com/id/1234567890/photo/slug.jpg
  #   gty.im/1234567890
  #   gettyimages.com/photos/...?...assetid=1234567890 (rare)
  ASSET_ID_PATTERNS = [
    %r{gty\.im/(\d{6,})},
    %r{/id/(\d{6,})/},
    %r{/detail/[^?#]*?/(\d{6,})(?:[/?#]|$)},
    %r{[?&]assetid=(\d{6,})}i,
    %r{/(\d{8,})(?:[/?#]|$)}  # last resort: any long numeric path segment
  ].freeze

  CSV_COLUMNS = %w[
  source asset_id source_url status title caption photographer credit collection
  date_created date_text license_model rights width height keywords people
  thumbnail_url fetched_via
  ].freeze

  validates :asset_id, presence: true, uniqueness: { scope: :source }
  validates :source, inclusion: { in: MetadataClient::SOURCES.keys }
  validates :source_url, presence: true
  validates :status, inclusion: { in: STATUSES }

  after_create_commit :enqueue_fetch

  scope :done,    -> { where(status: "done") }
  scope :pending, -> { where(status: "pending") }
  scope :keyword, ->(word) { 
    where("EXISTS (SELECT 1 FROM json_each(getty_assets.keywords) WHERE value = ?)", word)
  }

  # Returns the asset id string or nil if the URL doesn't look like a Getty URL.
  def self.extract_asset_id(url)
    url = url.to_s.strip
    return nil unless url.match?(/getty|gty\.im/i)

    ASSET_ID_PATTERNS.each do |pattern|
      return Regexp.last_match(1) if url.match?(pattern) && (url =~ pattern)
    end
    nil
  end

  # Bulk create from a newline/comma/whitespace-separated blob of URLs.
  # Returns [created, skipped_duplicates, unparseable].
  def self.import_urls(text)
    created, dupes, bad = [], [], []

    text.to_s.split(/[\s,]+/).map(&:strip).reject(&:blank?).uniq.each do |url|
      source, id = MetadataClient.identify(url)
      if id.nil?
        bad << url
      elsif exists?(source: source, asset_id: id)
        dupes << url
      else
        created << create!(source: source, asset_id: id, source_url: url)
      end
    end

    [created, dupes, bad]
  end

  def self.to_csv(scope = all)
    CSV.generate(headers: true) do |csv|
      csv << CSV_COLUMNS
      scope.find_each { |asset| csv << asset.csv_row }
    end
  end

  def csv_row
    CSV_COLUMNS.map do |col|
      value = public_send(col)
      value.is_a?(Array) ? value.join("; ") : value
    end
  end

  def refetch!
    update!(status: "pending", error_message: nil)
    enqueue_fetch
  end

  private

  def enqueue_fetch
    FetchGettyMetadataJob.perform_later(id)
  end
end
