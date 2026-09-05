class Loan < ApplicationRecord
  include DatasetRecord

  belongs_to :customer

  scope :started_between, ->(from, to) { where(start_date: from..to) }
end
