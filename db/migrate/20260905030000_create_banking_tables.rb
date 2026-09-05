# The synthetic banking dataset (Kaggle: akrambelha/synthetic-banking-dataset,
# CC BY 4.0), one table per source table. The source's string ids become the
# primary keys so every row keeps its original identity; the other column
# names are the dataset's own.
class CreateBankingTables < ActiveRecord::Migration[8.1]
  def change
    create_table :customers, id: :string do |t|
      t.string :first_name
      t.string :last_name
      t.string :email
      t.string :city
      t.integer :credit_score
      t.datetime :created_at
    end
    add_index :customers, :city
    add_index :customers, :credit_score
    add_index :customers, :email
    add_index :customers, [ :last_name, :first_name ]

    create_table :accounts, id: :string do |t|
      t.string :customer_id, null: false
      t.string :account_type, null: false
      t.decimal :balance_usd, precision: 14, scale: 2
      t.datetime :open_date
    end
    add_index :accounts, :customer_id
    add_index :accounts, :account_type
    add_foreign_key :accounts, :customers

    create_table :cards, id: :string do |t|
      t.string :account_id, null: false
      t.string :card_type, null: false
      t.datetime :expiration_date
    end
    add_index :cards, :account_id
    add_index :cards, :card_type
    add_foreign_key :cards, :accounts

    create_table :merchants, id: :string do |t|
      t.string :merchant_name
      t.string :city
    end
    add_index :merchants, :city

    create_table :branches, id: :string do |t|
      t.string :branch_name
      t.string :manager_name
      t.string :city
      t.string :country
    end

    create_table :loans, id: :string do |t|
      t.string :customer_id, null: false
      t.decimal :loan_amount, precision: 14, scale: 2
      t.decimal :interest_rate, precision: 5, scale: 2
      t.datetime :start_date
    end
    add_index :loans, :customer_id
    add_index :loans, :start_date
    add_foreign_key :loans, :customers

    create_table :transactions, id: :string do |t|
      t.string :account_id, null: false
      t.string :merchant_id, null: false
      t.decimal :amount_usd, precision: 12, scale: 2
      t.datetime :transaction_date
    end
    add_index :transactions, :account_id
    add_index :transactions, :merchant_id
    add_index :transactions, :transaction_date
    add_foreign_key :transactions, :accounts
    add_foreign_key :transactions, :merchants
  end
end
