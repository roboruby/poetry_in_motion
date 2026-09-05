# A card or account transaction against a merchant. Amounts in the dataset
# are all positive (purchases); the sign carries no direction.
class Transaction < ApplicationRecord
  include DatasetRecord

  belongs_to :account
  belongs_to :merchant
  has_one :customer, through: :account

  scope :between, ->(from, to) { where(transaction_date: from..to) }
  scope :newest_first, -> { order(transaction_date: :desc) }
end
