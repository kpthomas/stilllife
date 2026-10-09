class CreateGettyAssets < ActiveRecord::Migration[8.0]
  def change
    create_table :getty_assets do |t|
      t.string :asset_id, null: false
      t.string :source_url, null: false
      t.string :status, null: false, default: "pending" # pending | done | failed | not_found
      t.text   :error_message
      t.string :fetched_via # oembed | api

      # Normalized fields, present from both oEmbed and the v3 API where available
      t.string  :title
      t.text    :caption
      t.string  :photographer
      t.string  :credit
      t.string  :collection
      t.date    :date_created
      t.string  :license_model
      t.integer :width
      t.integer :height
      t.string  :thumbnail_url
      t.json  :keywords, null: false, default: []
      t.json  :people,   null: false, default: []

      t.json :raw, null: false, default: {}

      t.timestamps
    end

    add_index :getty_assets, :asset_id, unique: true
    add_index :getty_assets, :status
    add_index :getty_assets, :date_created
  end
end
