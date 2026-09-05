class LoansTool < ApplicationTool
  ORDERS = { "newest" => { start_date: :desc }, "oldest" => { start_date: :asc }, "largest" => { loan_amount: :desc },
             "smallest" => { loan_amount: :asc }, "highest_rate" => { interest_rate: :desc }, "lowest_rate" => { interest_rate: :asc } }.freeze

  description "List loans with filters (customer, amount range, interest rate range, start date range) and a summary " \
              "(count, total exposure, average, min, max) over the whole filtered set."
  param :customer_id, required: false
  param :min_amount, type: :number, required: false
  param :max_amount, type: :number, required: false
  param :min_rate, type: :number, desc: "Interest rate percent", required: false
  param :max_rate, type: :number, required: false
  param :from, desc: "Start date lower bound, ISO date", required: false
  param :to, desc: "Start date upper bound, ISO date", required: false
  param :order, desc: "newest (default) | oldest | largest | smallest | highest_rate | lowest_rate", required: false
  param :limit, type: :integer, desc: "Rows to return, default 25, max 200", required: false

  def execute(customer_id: nil, min_amount: nil, max_amount: nil, min_rate: nil, max_rate: nil, from: nil, to: nil, order: nil, limit: nil)
    scope = Loan.all
    scope = scope.where(customer_id: customer_id.to_s.strip.upcase) if customer_id.present?
    scope = scope.where(loan_amount: min_amount..) if min_amount
    scope = scope.where(loan_amount: ..max_amount) if max_amount
    scope = scope.where(interest_rate: min_rate..) if min_rate
    scope = scope.where(interest_rate: ..max_rate) if max_rate
    scope = scope.where(start_date: time_or(from, DATA_START).beginning_of_day..) if from.present?
    scope = scope.where(start_date: ..time_or(to, DATA_END).end_of_day) if to.present?

    rows = scope.order(ORDERS.fetch(order.to_s, ORDERS["newest"])).limit(limit_of(limit, default: 25)).includes(:customer).map do |loan|
      { id: loan.id, customer_id: loan.customer_id, customer: loan.customer&.full_name, credit_score: loan.customer&.credit_score,
        amount: money(loan.loan_amount), interest_rate: loan.interest_rate.to_f, started: date_of(loan.start_date) }
    end
    summary = summary_of(scope, :loan_amount).merge(average_rate: scope.average(:interest_rate).to_f.round(2))
    ok(summary: summary, returned: rows.size, rows: rows)
  end
end
