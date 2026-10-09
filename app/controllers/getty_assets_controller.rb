class GettyAssetsController < ApplicationController
  def index
    @assets = GettyAsset.order(created_at: :desc).limit(500)

    respond_to do |format|
      format.html
      format.csv do
        send_data GettyAsset.to_csv(GettyAsset.done.order(:created_at)),
                  filename: "getty-metadata-#{Date.current}.csv",
                  type: "text/csv"
      end
    end
  end

  def show
    @asset = GettyAsset.find(params[:id])
  end

  def create
    created, dupes, bad = GettyAsset.import_urls(params[:urls])

    notice = "Queued #{created.size} asset#{'s' unless created.one?}."
    notice += " Skipped #{dupes.size} already-known." if dupes.any?
    notice += " Couldn't parse: #{bad.first(3).join(', ')}#{'…' if bad.size > 3}" if bad.any?

    redirect_to getty_assets_path, notice: notice
  end

  def refetch
    GettyAsset.find(params[:id]).refetch!
    redirect_back fallback_location: getty_assets_path, notice: "Refetching…"
  end
end
