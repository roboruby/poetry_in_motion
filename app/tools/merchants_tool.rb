class MerchantsTool < ApplicationTool
  description "Merchants with their transaction count and volume, ranked by volume (default) or count; " \
              "filter by name fragment, city, and a transaction date window."
  param :query, desc: "Merchant name fragment", required: false
  param :city, required: false
  param :from, desc: "ISO date; counts only transactions from this date", required: false
  param :to, desc: "ISO date", required: false
  param :order, desc: "volume (default) | count | name", required: false
  param :limit, type: :integer, desc: "Rows to return, default 10, max 100", required: false

  def execute(query: nil, city: nil, from: nil, to: nil, order: nil, limit: nil)
    scope = Merchant.left_joins(:transactions)
    scope = scope.where("merchants.merchant_name LIKE ?", "%#{Merchant.sanitize_sql_like(query.to_s.strip)}%") if query.present?
    scope = scope.where("LOWER(merchants.city) = ?", city.to_s.downcase) if city.present?
    if from.present? || to.present?
      window = time_or(from, DATA_START).beginning_of_day..time_or(to, DATA_END).end_of_day
      scope = scope.where(transactions: { transaction_date: window })
    end
    ordering = case order.to_s
    when "count" then Arel.sql("transaction_count DESC")
    when "name" then Arel.sql("merchants.merchant_name ASC")
    else Arel.sql("volume DESC")
    end
    rows = scope.group("merchants.id")
                .order(ordering)
                .limit(limit_of(limit, default: 10, max: 100))
                .pluck(Arel.sql("merchants.id"), Arel.sql("merchants.merchant_name"), Arel.sql("merchants.city"),
                       Arel.sql("COUNT(transactions.id) AS transaction_count"), Arel.sql("COALESCE(ROUND(SUM(transactions.amount_usd), 2), 0) AS volume"))
                .map { |id, name, merchant_city, count, volume| { id: id, name: name, city: merchant_city, transactions: count, volume: volume.to_f } }
    ok(returned: rows.size, rows: rows)
  end
end
