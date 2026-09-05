module Banking
  # Copies every table of the dataset's SQLite database into this app's
  # database in one pass: the source file is attached to the connection and
  # each table is filled with INSERT ... SELECT, which moves the 1.26 million
  # rows in seconds and keeps the dataset's own ids. Re-running replaces the
  # rows, so the import is idempotent.
  class Importer
    # Destination table => [destination columns, source columns] in copy order
    # (parents before children so the foreign keys hold).
    TABLES = {
      "customers" => [ %w[id first_name last_name email city credit_score created_at],
                       %w[customer_id first_name last_name email city credit_score created_at] ],
      "merchants" => [ %w[id merchant_name city], %w[merchant_id merchant_name city] ],
      "branches" => [ %w[id branch_name manager_name city country],
                      %w[branch_id branch_name manager_name city country] ],
      "accounts" => [ %w[id customer_id account_type balance_usd open_date],
                      %w[account_id customer_id account_type balance_usd open_date] ],
      "cards" => [ %w[id account_id card_type expiration_date],
                   %w[card_id account_id card_type expiration_date] ],
      "loans" => [ %w[id customer_id loan_amount interest_rate start_date],
                   %w[loan_id customer_id loan_amount interest_rate start_date] ],
      "transactions" => [ %w[id account_id merchant_id amount_usd transaction_date],
                          %w[transaction_id account_id merchant_id amount_usd transaction_date] ]
    }.freeze

    attr_reader :source

    def initialize(source = nil)
      @source = Pathname(source || Dataset.new.database_path)
    end

    # @return [Hash{String => Integer}] row counts per table after the copy
    def call
      raise ArgumentError, "no dataset database at #{source} (run bin/rails banking:download)" unless source.exist?

      connection.execute("ATTACH DATABASE #{connection.quote(source.to_s)} AS src")
      begin
        connection.transaction do
          TABLES.keys.reverse_each { |table| connection.execute("DELETE FROM #{table}") }
          TABLES.each do |table, (destination, origin)|
            connection.execute(<<~SQL)
              INSERT INTO #{table} (#{destination.join(", ")})
              SELECT #{origin.join(", ")} FROM src.#{table}
            SQL
          end
        end
      ensure
        connection.execute("DETACH DATABASE src")
      end
      counts
    end

    def counts
      TABLES.keys.to_h { |table| [ table, connection.select_value("SELECT COUNT(*) FROM #{table}").to_i ] }
    end

    private

    def connection
      ActiveRecord::Base.connection
    end
  end
end
