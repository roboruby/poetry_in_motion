class SearchCustomersTool < ApplicationTool
  ORDERS = {
    "credit_score_desc" => { credit_score: :desc }, "credit_score_asc" => { credit_score: :asc },
    "newest" => { created_at: :desc }, "oldest" => { created_at: :asc }, "name" => { last_name: :asc, first_name: :asc }
  }.freeze

  description "Find customers by name or email fragment, city, credit band, or credit score range. " \
              "Returns up to 100 customers with their account count and total balance, plus the total match count."
  parameter :query, description: "Name or email fragment", required: false
  parameter :city, description: "Exact city name", required: false
  parameter :credit_band, description: "Excellent | Good | Fair | Poor | Very poor", required: false
  parameter :min_credit_score, type: :integer, required: false
  parameter :max_credit_score, type: :integer, required: false
  parameter :order, description: "credit_score_desc (default) | credit_score_asc | newest | oldest | name", required: false
  parameter :limit, type: :integer, description: "Rows to return, default 20, max 100", required: false

  def execute(query: nil, city: nil, credit_band: nil, min_credit_score: nil, max_credit_score: nil, order: nil, limit: nil)
    scope = Customer.all
    scope = scope.named(query) if query.present?
    scope = scope.in_city(city) if city.present?
    if credit_band.present?
      range = Customer::CREDIT_BANDS.find { |name, _range| name.casecmp?(credit_band.to_s.strip) }&.last
      return failure("unknown credit band #{credit_band.inspect}; use #{Customer::CREDIT_BANDS.keys.join(", ")}") unless range

      scope = scope.where(credit_score: range)
    end
    scope = scope.where(credit_score: min_credit_score..) if min_credit_score
    scope = scope.where(credit_score: ..max_credit_score) if max_credit_score
    scope = scope.order(ORDERS.fetch(order.to_s, ORDERS["credit_score_desc"]))

    customers = scope.limit(limit_of(limit, default: 20, max: 100)).includes(:accounts).to_a
    rows = customers.map do |customer|
      customer_row(customer).merge(accounts: customer.accounts.size,
                                   total_balance: money(customer.accounts.sum(&:balance_usd)))
    end
    ok(total_matches: scope.count, returned: rows.size, rows: rows)
  end
end
