# Base for the analyst's tools. Every tool answers with a JSON string the
# model reads; `{ "error": ... }` is the recoverable-failure convention.
class ApplicationTool < RubyLLM::Tool
  MAX_LIMIT = 200
  # The dataset ends here; "recent" and "expired" are judged against it.
  DATA_END = Time.utc(2025, 12, 31, 23, 59, 59)
  DATA_START = Time.utc(2019, 1, 1)

  attr_reader :chat

  def initialize(chat = nil)
    @chat = chat
    super()
  end

  private

  def ok(payload)
    JSON.generate(payload)
  end

  def failure(text)
    JSON.generate({ error: text })
  end

  def limit_of(limit, default:, max: MAX_LIMIT)
    (limit.presence || default).to_i.clamp(1, max)
  end

  def time_or(value, default)
    return default if value.blank?

    Time.zone.parse(value.to_s) || default
  rescue ArgumentError
    default
  end

  def money(value)
    value.to_f.round(2)
  end

  def date_of(time)
    time&.to_date&.iso8601
  end

  def customer_row(customer)
    { id: customer.id, name: customer.full_name, email: customer.email, city: customer.city,
      credit_score: customer.credit_score, credit_band: customer.credit_band,
      customer_since: date_of(customer.created_at) }
  end

  def transaction_row(transaction)
    { id: transaction.id, date: transaction.transaction_date&.iso8601, amount: money(transaction.amount_usd),
      account_id: transaction.account_id, account_type: transaction.account&.account_type,
      customer_id: transaction.account&.customer_id, customer: transaction.account&.customer&.full_name,
      merchant_id: transaction.merchant_id, merchant: transaction.merchant&.merchant_name,
      merchant_city: transaction.merchant&.city }
  end

  def summary_of(scope, column)
    { count: scope.count, total: money(scope.sum(column)), average: money(scope.average(column)),
      min: money(scope.minimum(column)), max: money(scope.maximum(column)) }
  end
end
