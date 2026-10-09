class AddSourceToGettyAssets < ActiveRecord::Migration[8.0]
  def change
    add_column :getty_assets, :source, :string, null: false, default: "getty" # getty | loc
    add_column :getty_assets, :date_text, :string   # source's own date string, e.g. "1910/1920" or "circa 1957"
    add_column :getty_assets, :rights, :text        # LoC rights advisory; Getty license notes
    add_column :getty_assets, :source_id, :string   # LoC reproduction number, Getty asset id (duplicated for clarity)

    add_index :getty_assets, :source

    # asset_id was unique on its own; now it's unique per source
    remove_index :getty_assets, :asset_id
    add_index :getty_assets, [:source, :asset_id], unique: true
  end
end
