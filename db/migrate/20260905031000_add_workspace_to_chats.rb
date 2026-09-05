# A chat is a workspace: it gets a title, and a log of the A2UI messages the
# agent emitted (ui_events), replayed to rebuild the surfaces on each request.
class AddWorkspaceToChats < ActiveRecord::Migration[8.1]
  def change
    add_column :chats, :title, :string

    create_table :ui_events do |t|
      t.references :chat, null: false, foreign_key: true
      t.references :message, null: true, foreign_key: true
      t.string :surface_id, null: false
      t.string :kind, null: false
      t.string :title
      t.json :payload, null: false
      t.datetime :created_at, null: false
    end
    add_index :ui_events, [ :chat_id, :surface_id ]
  end
end
