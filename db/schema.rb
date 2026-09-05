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

ActiveRecord::Schema[8.1].define(version: 2026_09_05_031000) do
  create_table "accounts", id: :string, force: :cascade do |t|
    t.string "account_type", null: false
    t.decimal "balance_usd", precision: 14, scale: 2
    t.string "customer_id", null: false
    t.datetime "open_date"
    t.index ["account_type"], name: "index_accounts_on_account_type"
    t.index ["customer_id"], name: "index_accounts_on_customer_id"
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "branches", id: :string, force: :cascade do |t|
    t.string "branch_name"
    t.string "city"
    t.string "country"
    t.string "manager_name"
  end

  create_table "cards", id: :string, force: :cascade do |t|
    t.string "account_id", null: false
    t.string "card_type", null: false
    t.datetime "expiration_date"
    t.index ["account_id"], name: "index_cards_on_account_id"
    t.index ["card_type"], name: "index_cards_on_card_type"
  end

  create_table "chats", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "model_id"
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["model_id"], name: "index_chats_on_model_id"
  end

  create_table "customers", id: :string, force: :cascade do |t|
    t.string "city"
    t.datetime "created_at"
    t.integer "credit_score"
    t.string "email"
    t.string "first_name"
    t.string "last_name"
    t.index ["city"], name: "index_customers_on_city"
    t.index ["credit_score"], name: "index_customers_on_credit_score"
    t.index ["email"], name: "index_customers_on_email"
    t.index ["last_name", "first_name"], name: "index_customers_on_last_name_and_first_name"
  end

  create_table "loans", id: :string, force: :cascade do |t|
    t.string "customer_id", null: false
    t.decimal "interest_rate", precision: 5, scale: 2
    t.decimal "loan_amount", precision: 14, scale: 2
    t.datetime "start_date"
    t.index ["customer_id"], name: "index_loans_on_customer_id"
    t.index ["start_date"], name: "index_loans_on_start_date"
  end

  create_table "merchants", id: :string, force: :cascade do |t|
    t.string "city"
    t.string "merchant_name"
    t.index ["city"], name: "index_merchants_on_city"
  end

  create_table "messages", force: :cascade do |t|
    t.integer "cache_creation_tokens"
    t.integer "cached_tokens"
    t.integer "chat_id", null: false
    t.text "content"
    t.json "content_raw"
    t.datetime "created_at", null: false
    t.integer "input_tokens"
    t.integer "model_id"
    t.integer "output_tokens"
    t.string "role", null: false
    t.text "thinking_signature"
    t.text "thinking_text"
    t.integer "thinking_tokens"
    t.integer "tool_call_id"
    t.datetime "updated_at", null: false
    t.index ["chat_id"], name: "index_messages_on_chat_id"
    t.index ["model_id"], name: "index_messages_on_model_id"
    t.index ["role"], name: "index_messages_on_role"
    t.index ["tool_call_id"], name: "index_messages_on_tool_call_id"
  end

  create_table "models", force: :cascade do |t|
    t.json "capabilities", default: []
    t.integer "context_window"
    t.datetime "created_at", null: false
    t.string "family"
    t.date "knowledge_cutoff"
    t.integer "max_output_tokens"
    t.json "metadata", default: {}
    t.json "modalities", default: {}
    t.datetime "model_created_at"
    t.string "model_id", null: false
    t.string "name", null: false
    t.json "pricing", default: {}
    t.string "provider", null: false
    t.datetime "updated_at", null: false
    t.index ["family"], name: "index_models_on_family"
    t.index ["provider", "model_id"], name: "index_models_on_provider_and_model_id", unique: true
    t.index ["provider"], name: "index_models_on_provider"
  end

  create_table "tool_calls", force: :cascade do |t|
    t.json "arguments", default: {}
    t.datetime "created_at", null: false
    t.integer "message_id", null: false
    t.string "name", null: false
    t.text "thought_signature"
    t.string "tool_call_id", null: false
    t.datetime "updated_at", null: false
    t.index ["message_id"], name: "index_tool_calls_on_message_id"
    t.index ["name"], name: "index_tool_calls_on_name"
    t.index ["tool_call_id"], name: "index_tool_calls_on_tool_call_id", unique: true
  end

  create_table "transactions", id: :string, force: :cascade do |t|
    t.string "account_id", null: false
    t.decimal "amount_usd", precision: 12, scale: 2
    t.string "merchant_id", null: false
    t.datetime "transaction_date"
    t.index ["account_id"], name: "index_transactions_on_account_id"
    t.index ["merchant_id"], name: "index_transactions_on_merchant_id"
    t.index ["transaction_date"], name: "index_transactions_on_transaction_date"
  end

  create_table "ui_events", force: :cascade do |t|
    t.integer "chat_id", null: false
    t.datetime "created_at", null: false
    t.string "kind", null: false
    t.integer "message_id"
    t.json "payload", null: false
    t.string "surface_id", null: false
    t.string "title"
    t.index ["chat_id", "surface_id"], name: "index_ui_events_on_chat_id_and_surface_id"
    t.index ["chat_id"], name: "index_ui_events_on_chat_id"
    t.index ["message_id"], name: "index_ui_events_on_message_id"
  end

  add_foreign_key "accounts", "customers"
  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "cards", "accounts"
  add_foreign_key "chats", "models"
  add_foreign_key "loans", "customers"
  add_foreign_key "messages", "chats"
  add_foreign_key "messages", "models"
  add_foreign_key "messages", "tool_calls"
  add_foreign_key "tool_calls", "messages"
  add_foreign_key "transactions", "accounts"
  add_foreign_key "transactions", "merchants"
  add_foreign_key "ui_events", "chats"
  add_foreign_key "ui_events", "messages"
end
