require "test_helper"

class DataToolsTest < ActiveSupport::TestCase
  def run_tool(tool, **args)
    JSON.parse(tool.new.execute(**args))
  end

  test "bank overview totals" do
    result = run_tool(BankOverviewTool)
    assert_equal 2, result["customers"]["count"]
    assert_equal 3, result["accounts"]["count"]
    assert_equal 500.0, result["transactions"]["volume"]
    assert_equal 1, result["cards"]["expired"]
    assert_equal 5, result["credit_bands"].size
  end

  test "search customers by band and query" do
    result = run_tool(SearchCustomersTool, credit_band: "Excellent")
    assert_equal [ "Ada Lovelace" ], result["rows"].map { |row| row["name"] }
    assert_equal 92500.5, result["rows"].first["total_balance"]
    assert_match(/unknown credit band/, run_tool(SearchCustomersTool, credit_band: "Platinum")["error"])
  end

  test "customer profile gathers accounts, cards, loans, and transactions" do
    result = run_tool(CustomerProfileTool, customer_id: "cus0000000000ada")
    assert_equal "Ada Lovelace", result["customer"]["name"]
    assert_equal 2, result["accounts"].size
    assert_equal 1, result["loans"].size
    assert_equal 2, result["recent_transactions"].size
    assert_match(/no customer/, run_tool(CustomerProfileTool, customer_id: "nope")["error"])
  end

  test "transactions filter and summarize the whole set" do
    result = run_tool(TransactionsTool, customer_id: "CUS0000000000ADA", limit: 1, order: "largest")
    assert_equal 2, result["summary"]["count"]
    assert_equal 200.0, result["summary"]["total"]
    assert_equal 1, result["returned"]
    assert_equal 120.0, result["rows"].first["amount"]
    assert_equal "Babbage Books", result["rows"].first["merchant"]
  end

  test "aggregate groups transaction volume by month and merchant" do
    result = run_tool(AggregateTool, metric: "transaction_volume", group_by: "month", from: "2025-12-01")
    assert_equal [ { "key" => "2025-12", "value" => 380.0 } ], result["rows"]
    result = run_tool(AggregateTool, metric: "transaction_count", group_by: "merchant")
    assert_equal [ "Babbage Books", "Turing Grocers" ], result["rows"].map { |row| row["key"] }
    result = run_tool(AggregateTool, metric: "account_balance", group_by: "credit_band")
    assert_equal({ "Excellent" => 92500.5, "Very poor" => 3200.25 }, result["rows"].to_h { |row| [ row["key"], row["value"] ] })
  end

  test "aggregate totals and refuses unsupported pairs" do
    assert_equal 2, run_tool(AggregateTool, metric: "customer_count")["total"]
    assert_match(/cannot be grouped/, run_tool(AggregateTool, metric: "loan_exposure", group_by: "merchant")["error"])
    assert_match(/unknown metric/, run_tool(AggregateTool, metric: "profit")["error"])
  end

  test "loans, merchants, and branches" do
    assert_equal 450000.0, run_tool(LoansTool, min_rate: 5)["summary"]["total"]
    merchants = run_tool(MerchantsTool, order: "count")["rows"]
    assert_equal "Babbage Books", merchants.first["name"]
    assert_equal 2, merchants.first["transactions"]
    assert_equal "Diane Larson", run_tool(BranchesTool, query: "east")["rows"].first["manager"]
  end
end
