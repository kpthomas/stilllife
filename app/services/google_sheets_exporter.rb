# Second-pass stub. Appends GettyAsset rows to a Google Sheet.
#
# Setup:
#   bundle add google-apis-sheets_v4 googleauth
#   1. Create a service account in Google Cloud, enable the Sheets API.
#   2. Download its JSON key; set GOOGLE_APPLICATION_CREDENTIALS to its path.
#   3. Share the target spreadsheet with the service account's email (Editor).
#   4. Set GOOGLE_SHEET_ID to the id from the sheet URL.
#
# Usage:
#   GoogleSheetsExporter.new.append(GettyAsset.done.where("updated_at > ?", 1.day.ago))
#
require "google/apis/sheets_v4"
require "googleauth"

class GoogleSheetsExporter
  SCOPE = "https://www.googleapis.com/auth/spreadsheets"

  def initialize(sheet_id: ENV.fetch("GOOGLE_SHEET_ID"), tab: "Sheet1")
    @sheet_id = sheet_id
    @tab = tab
    @service = Google::Apis::SheetsV4::SheetsService.new
    @service.authorization = Google::Auth::ServiceAccountCredentials.make_creds(scope: SCOPE)
  end

  # Writes the header row if the tab is empty, then appends one row per asset.
  def append(assets)
    ensure_header!
    rows   = assets.map { AssetCsv.row(it) }
    return 0 if rows.empty?

    value_range = Google::Apis::SheetsV4::ValueRange.new(values: rows)
    @service.append_spreadsheet_value(
      @sheet_id, "#{@tab}!A1", value_range,
      value_input_option: "USER_ENTERED", insert_data_option: "INSERT_ROWS"
    )
    rows.size
  end

  private

  def ensure_header!
    existing = @service.get_spreadsheet_values(@sheet_id, "#{@tab}!A1:A1").values
    return if existing.present?

    header = Google::Apis::SheetsV4::ValueRange.new(values: [AssetCsv.headers])
    @service.update_spreadsheet_value(@sheet_id, "#{@tab}!A1", header, value_input_option: "RAW")
  end
end
