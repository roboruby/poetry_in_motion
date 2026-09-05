class Account < ApplicationRecord
  include DatasetRecord

  TYPES = %w[Business Checking Savings].freeze

  belongs_to :customer
  has_many :cards, dependent: :restrict_with_exception
  has_many :transactions, dependent: :restrict_with_exception

  scope :of_type, ->(type) { where(account_type: type) }
end
