require "test_helper"

class CustomerTest < ActiveSupport::TestCase
  test "credit bands follow the dataset's boundaries" do
    assert_equal "Excellent", Customer.credit_band_for(750)
    assert_equal "Good", Customer.credit_band_for(749)
    assert_equal "Fair", Customer.credit_band_for(650)
    assert_equal "Poor", Customer.credit_band_for(600)
    assert_equal "Very poor", Customer.credit_band_for(599)
    assert_nil Customer.credit_band_for(nil)
  end

  test "named matches first, last, full name, and email" do
    assert_equal [ customers(:ada) ], Customer.named("Ada").to_a
    assert_equal [ customers(:ada) ], Customer.named("ada love").to_a
    assert_equal [ customers(:grace) ], Customer.named("grace@example").to_a
  end

  test "dataset rows are read-only" do
    assert customers(:ada).readonly?
    assert_raises(ActiveRecord::ReadOnlyRecord) { customers(:ada).update!(city: "Paris") }
  end

  test "associations reach across the dataset" do
    ada = customers(:ada)
    assert_equal 2, ada.accounts.count
    assert_equal 1, ada.cards.count
    assert_equal 2, ada.transactions.count
    assert_equal 1, ada.loans.count
  end
end
