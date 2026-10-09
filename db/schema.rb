# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_08_170000) do
  create_table "getty_assets", force: :cascade do |t|
    t.string "asset_id", null: false
    t.string "source_url", null: false
    t.string "status", default: "pending", null: false
    t.text "error_message"
    t.string "fetched_via"
    t.string "title"
    t.text "caption"
    t.string "photographer"
    t.string "credit"
    t.string "collection"
    t.date "date_created"
    t.string "license_model"
    t.integer "width"
    t.integer "height"
    t.string "thumbnail_url"
    t.json "keywords", default: [], null: false
    t.json "people", default: [], null: false
    t.json "raw", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "source", default: "getty", null: false
    t.string "date_text"
    t.text "rights"
    t.string "source_id"
    t.index ["date_created"], name: "index_getty_assets_on_date_created"
    t.index ["source", "asset_id"], name: "index_getty_assets_on_source_and_asset_id", unique: true
    t.index ["source"], name: "index_getty_assets_on_source"
    t.index ["status"], name: "index_getty_assets_on_status"
  end
end
