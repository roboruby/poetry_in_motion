# Grouped metrics for charts and breakdowns, computed in SQL over the whole
# dataset. A metric picks its base table; a grouping picks the key; joins
# follow from the pair. Unsupported pairs answer with the supported list.
class AggregateTool < ApplicationTool
  CREDIT_BAND_SQL = "CASE WHEN customers.credit_score >= 750 THEN 'Excellent' " \
                    "WHEN customers.credit_score >= 700 THEN 'Good' WHEN customers.credit_score >= 650 THEN 'Fair' " \
                    "WHEN customers.credit_score >= 600 THEN 'Poor' ELSE 'Very poor' END".freeze

  BASES = {
    transactions: { model: "Transaction", date: "transactions.transaction_date",
                    joins: { accounts: :account, customers: { account: :customer }, merchants: :merchant } },
    accounts: { model: "Account", date: "accounts.open_date", joins: { customers: :customer } },
    customers: { model: "Customer", date: "customers.created_at", joins: {} },
    loans: { model: "Loan", date: "loans.start_date", joins: { customers: :customer } },
    cards: { model: "Card", date: "cards.expiration_date", joins: { accounts: :account, customers: { account: :customer } } }
  }.freeze

  METRICS = {
    "transaction_count" => [ :transactions, "COUNT(*)" ],
    "transaction_volume" => [ :transactions, "ROUND(SUM(transactions.amount_usd), 2)" ],
    "average_transaction" => [ :transactions, "ROUND(AVG(transactions.amount_usd), 2)" ],
    "account_count" => [ :accounts, "COUNT(*)" ],
    "account_balance" => [ :accounts, "ROUND(SUM(accounts.balance_usd), 2)" ],
    "average_balance" => [ :accounts, "ROUND(AVG(accounts.balance_usd), 2)" ],
    "customer_count" => [ :customers, "COUNT(*)" ],
    "average_credit_score" => [ :customers, "ROUND(AVG(customers.credit_score), 1)" ],
    "loan_count" => [ :loans, "COUNT(*)" ],
    "loan_exposure" => [ :loans, "ROUND(SUM(loans.loan_amount), 2)" ],
    "average_loan" => [ :loans, "ROUND(AVG(loans.loan_amount), 2)" ],
    "average_interest_rate" => [ :loans, "ROUND(AVG(loans.interest_rate), 2)" ],
    "card_count" => [ :cards, "COUNT(*)" ]
  }.freeze

  # group_by => [table the key lives on (nil = the base's date), SQL]
  GROUPS = {
    "none" => nil,
    "month" => [ nil, "strftime('%%Y-%%m', %s)" ],
    "year" => [ nil, "strftime('%%Y', %s)" ],
    "account_type" => [ :accounts, "accounts.account_type" ],
    "card_type" => [ :cards, "cards.card_type" ],
    "customer_city" => [ :customers, "customers.city" ],
    "merchant" => [ :merchants, "merchants.merchant_name" ],
    "merchant_city" => [ :merchants, "merchants.city" ],
    "credit_band" => [ :customers, CREDIT_BAND_SQL ]
  }.freeze

  description "Grouped metrics for charts and breakdowns. metric: #{METRICS.keys.join(" | ")}. " \
              "group_by: #{GROUPS.keys.join(" | ")} (month and year use the base table's date: transaction date, account open date, " \
              "customer since, loan start, card expiry). Filters: from/to on that date, account_type, card_type, city (customer city), credit_band."
  param :metric, desc: "One of the metrics listed in the description", required: true
  param :group_by, desc: "One of the groupings listed in the description; none returns a single total", required: false
  param :from, desc: "ISO date lower bound on the base date", required: false
  param :to, desc: "ISO date upper bound on the base date", required: false
  param :account_type, desc: "Business | Checking | Savings", required: false
  param :card_type, desc: "Credit | Debit", required: false
  param :city, desc: "Customer city", required: false
  param :credit_band, desc: "Excellent | Good | Fair | Poor | Very poor", required: false
  param :order, desc: "value_desc (default for categories) | value_asc | key_asc (default for month/year) | key_desc", required: false
  param :limit, type: :integer, desc: "Groups to return, default 12, max 100", required: false

  def execute(metric:, group_by: nil, from: nil, to: nil, account_type: nil, card_type: nil, city: nil, credit_band: nil, order: nil, limit: nil)
    base_name, aggregate = METRICS[metric.to_s]
    return failure("unknown metric #{metric.inspect}; use #{METRICS.keys.join(", ")}") unless base_name

    base = BASES.fetch(base_name)
    group = group_by.presence || "none"
    return failure("unknown group_by #{group.inspect}; use #{GROUPS.keys.join(", ")}") unless GROUPS.key?(group)

    scope = base[:model].constantize.all
    needed = []
    key_sql = nil
    if (definition = GROUPS[group])
      table, sql = definition
      key_sql = table ? sql : format(sql, base[:date])
      needed << table if table
    end
    needed << :accounts if account_type.present?
    needed << :cards if card_type.present?
    needed << :customers if city.present? || credit_band.present?

    needed.uniq.each do |table|
      next if table == base_name

      join = base[:joins][table]
      return failure("#{metric} cannot be grouped or filtered by #{table}; supported: #{supported(base_name).join(", ")}") unless join

      scope = scope.joins(join)
    end

    scope = scope.where(Arel.sql(base[:date]) => time_or(from, DATA_START).beginning_of_day..) if from.present?
    scope = scope.where(Arel.sql(base[:date]) => ..time_or(to, DATA_END).end_of_day) if to.present?
    scope = scope.where(accounts: { account_type: account_type }) if account_type.present?
    scope = scope.where(cards: { card_type: card_type }) if card_type.present?
    scope = scope.where("LOWER(customers.city) = ?", city.to_s.downcase) if city.present?
    if credit_band.present?
      range = Customer::CREDIT_BANDS.find { |name, _r| name.casecmp?(credit_band.to_s.strip) }&.last
      return failure("unknown credit band #{credit_band.inspect}") unless range

      scope = scope.where(customers: { credit_score: range })
    end

    if key_sql.nil?
      value = scope.pick(Arel.sql(aggregate))
      return ok(metric: metric, group_by: "none", total: value.is_a?(Numeric) ? value : value.to_f)
    end

    ordering = order.presence || (%w[month year].include?(group) ? "key_asc" : "value_desc")
    order_sql = { "value_desc" => "value DESC", "value_asc" => "value ASC", "key_asc" => "key ASC", "key_desc" => "key DESC" }
                  .fetch(ordering) { return failure("unknown order #{order.inspect}") }
    rows = scope.group(Arel.sql(key_sql))
                .order(Arel.sql(order_sql))
                .limit(limit_of(limit, default: 12, max: 100))
                .pluck(Arel.sql("#{key_sql} AS key"), Arel.sql("#{aggregate} AS value"))
                .map { |key, value| { key: key, value: value.is_a?(Numeric) ? value : value.to_f } }
    ok(metric: metric, group_by: group, groups: scope.distinct.count(Arel.sql(key_sql)), rows: rows)
  end

  private

  def supported(base_name)
    joinable = [ base_name ] + BASES[base_name][:joins].keys
    GROUPS.filter_map { |name, definition| name if definition.nil? || definition.first.nil? || joinable.include?(definition.first) }
  end
end
