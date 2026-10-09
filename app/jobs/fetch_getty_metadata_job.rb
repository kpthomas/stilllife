class FetchGettyMetadataJob < ApplicationJob
  queue_as :getty

  retry_on GettyClient::Error, LocClient::Error, wait: :polynomially_longer, attempts: 5
  discard_on ActiveRecord::RecordNotFound

  def perform(getty_asset_id)
    asset = GettyAsset.find(getty_asset_id)
    return if asset.status == "done"


    attrs = MetadataClient.for(asset.source).fetch(asset.asset_id)
    asset.update!(attrs.merge(status: "done", error_message: nil))
  rescue GettyClient::NotFound, LocClient::NotFound => e
    asset.update!(status: "not_found", error_message: e.message)
  rescue GettyClient::Error, LocClient::Error => e
    asset.update_columns(status: "failed", error_message: e.message)
    raise
  end
end
