class Merchant < ApplicationRecord
  include DatasetRecord

  has_many :transactions, dependent: :restrict_with_exception
end
