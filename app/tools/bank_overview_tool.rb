# The bank at a glance: totals, mix, credit distribution, and the monthly
# transaction volume for the last year of data.
class BankOverviewTool < ApplicationTool
  description "Bank-wide totals: customers, accounts by type with balances, cards, loans, transactions, " \
              "credit score distribution, and monthly transaction volume for 2025. Call this first for any overview or dashboard."

  def execute
    ok(
      as_of: date_of(DATA_END),
      data_range: { from: date_of(DATA_START), to: date_of(DATA_END) },
      customers: { count: Customer.count, average_credit_score: Customer.average(:credit_score).to_f.round(1),
                   cities: Customer.distinct.count(:city) },
      accounts: { count: Account.count, total_balance: money(Account.sum(:balance_usd)), by_type: accounts_by_type },
      cards: { count: Card.count, by_type: Card.group(:card_type).count,
               expired: Card.expired(DATA_END).count, active: Card.active(DATA_END).count },
      loans: { count: Loan.count, exposure: money(Loan.sum(:loan_amount)),
               average_amount: money(Loan.average(:loan_amount)), average_rate: Loan.average(:interest_rate).to_f.round(2) },
      transactions: { count: Transaction.count, volume: money(Transaction.sum(:amount_usd)),
                      average: money(Transaction.average(:amount_usd)) },
      merchants: Merchant.count,
      branches: Branch.count,
      credit_bands: credit_bands,
      monthly_volume_2025: monthly_volume(2025)
    )
  end

  private

  def accounts_by_type
    Account.group(:account_type)
           .pluck(:account_type, Arel.sql("COUNT(*)"), Arel.sql("ROUND(SUM(balance_usd), 2)"))
           .map { |type, count, balance| { type: type, accounts: count, balance: balance.to_f } }
  end

  def credit_bands
    total = Customer.count
    Customer::CREDIT_BANDS.map do |name, range|
      count = Customer.where(credit_score: range).count
      { band: name, customers: count, share: total.zero? ? 0 : (count * 100.0 / total).round(2) }
    end
  end

  def monthly_volume(year)
    from = Time.utc(year)
    month = Arel.sql("strftime('%Y-%m', transaction_date)")
    Transaction.between(from, from.end_of_year)
               .group(month)
               .pluck(month, Arel.sql("COUNT(*)"), Arel.sql("ROUND(SUM(amount_usd), 2)"))
               .sort_by(&:first)
               .map { |key, count, volume| { month: key, transactions: count, volume: volume.to_f } }
  end
end
