class CreateInitialSchemaWithUuid < ActiveRecord::Migration[8.1]
  def change
    create_table :applications, id: false do |t|
      t.string :id, limit: 36, null: false, primary_key: true
      t.string :name, null: false
      t.string :token, null: false
      t.integer :chats_count, default: 0
      t.timestamps
    end

    add_index :applications, :token, unique: true

    create_table :users, id: false do |t|
      t.string :id, limit: 36, null: false, primary_key: true
      t.string :name, null: false
      t.string :email, null: false
      t.timestamps
    end

    add_index :users, :email, unique: true

    create_table :chats, id: false do |t|
      t.string :id, limit: 36, null: false, primary_key: true
      t.integer :number, null: false
      t.string :application_id, limit: 36, null: false
      t.string :user_id, limit: 36, null: false
      t.integer :messages_count, default: 0
      t.timestamps
    end

    add_foreign_key :chats, :applications
    add_foreign_key :chats, :users
    add_index :chats, [ :application_id ], unique: false

    create_table :messages, id: false do |t|
      t.string :id, limit: 36, null: false, primary_key: true
      t.integer :number, null: false
      t.text :text, null: false
      t.string :chat_id, limit: 36, null: false
      t.string :user_id, limit: 36, null: false
      t.timestamps
    end

    add_foreign_key :messages, :chats
    add_foreign_key :messages, :users
    add_index :messages, [ :chat_id ], unique: false
  end
end
