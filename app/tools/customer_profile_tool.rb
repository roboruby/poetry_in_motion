class CustomerProfileTool < ApplicationTool
  description "Everything about one customer: profile, accounts with balances and cards, loans, " \
              "the ten most recent transactions, and totals. Needs the customer id (CUS...)."
  param :customer_id, desc: "Customer id such as CUS000MKX5RHTAP", required: true

  def execute(customer_id:)
    customer = Customer.includes(accounts: :cards).find_by(id: customer_id.to_s.strip.upcase)
    return failure("no customer #{customer_id.inspect}; search_customers finds ids") unless customer

    accounts = customer.accounts.map do |account|
      { id: account.id, type: account.account_type, balance: money(account.balance_usd), opened: date_of(account.open_date),
        cards: account.cards.map { |card| { id: card.id, type: card.card_type, expires: date_of(card.expiration_date), expired: card.expired?(DATA_END) } } }
    end
    loans = customer.loans.order(start_date: :desc).map do |loan|
      { id: loan.id, amount: money(loan.loan_amount), interest_rate: loan.interest_rate.to_f, started: date_of(loan.start_date) }
    end
    transactions = customer.transactions.includes(:merchant, account: :customer).newest_first.limit(10).map { |t| transaction_row(t) }
    all = customer.transactions

    ok(
      customer: customer_row(customer),
      totals: { accounts: accounts.size, total_balance: money(customer.accounts.sum(:balance_usd)),
                cards: customer.cards.count, loans: loans.size, loan_exposure: money(customer.loans.sum(:loan_amount)),
                transactions: all.count, transaction_volume: money(all.sum(:amount_usd)) },
      accounts: accounts, loans: loans, recent_transactions: transactions
    )
  end
end
