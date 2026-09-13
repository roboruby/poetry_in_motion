class TransactionsTool < ApplicationTool
  ORDERS = { "newest" => { transaction_date: :desc }, "oldest" => { transaction_date: :asc },
             "largest" => { amount_usd: :desc }, "smallest" => { amount_usd: :asc } }.freeze

  description "List transactions with filters (customer, account, merchant, date range, amount range) and a summary " \
              "(count, total, average, min, max) over the whole filtered set. Use aggregate for charts and breakdowns."
  parameter :customer_id, required: false
  parameter :account_id, required: false
  parameter :merchant_id, required: false
  parameter :from, description: "ISO date, inclusive", required: false
  parameter :to, description: "ISO date, inclusive", required: false
  parameter :min_amount, type: :number, required: false
  parameter :max_amount, type: :number, required: false
  parameter :order, description: "newest (default) | oldest | largest | smallest", required: false
  parameter :limit, type: :integer, description: "Rows to return, default 25, max 200", required: false

  def execute(customer_id: nil, account_id: nil, merchant_id: nil, from: nil, to: nil, min_amount: nil, max_amount: nil, order: nil, limit: nil)
    scope = Transaction.all
    scope = scope.joins(:account).where(accounts: { customer_id: customer_id.to_s.strip.upcase }) if customer_id.present?
    scope = scope.where(account_id: account_id.to_s.strip.upcase) if account_id.present?
    scope = scope.where(merchant_id: merchant_id.to_s.strip.upcase) if merchant_id.present?
    scope = scope.where(transaction_date: time_or(from, DATA_START).beginning_of_day..) if from.present?
    scope = scope.where(transaction_date: ..time_or(to, DATA_END).end_of_day) if to.present?
    scope = scope.where(amount_usd: min_amount..) if min_amount
    scope = scope.where(amount_usd: ..max_amount) if max_amount

    rows = scope.order(ORDERS.fetch(order.to_s, ORDERS["newest"]))
                .limit(limit_of(limit, default: 25))
                .includes(:merchant, account: :customer)
                .map { |transaction| transaction_row(transaction) }
    ok(summary: summary_of(scope, :amount_usd), returned: rows.size, rows: rows)
  end
end
