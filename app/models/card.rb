class Card < ApplicationRecord
  include DatasetRecord

  TYPES = %w[Credit Debit].freeze

  belongs_to :account
  has_one :customer, through: :account

  scope :expired, ->(at = Time.current) { where(expiration_date: ...at) }
  scope :active, ->(at = Time.current) { where(expiration_date: at..) }

  def expired?(at = Time.current)
    expiration_date.present? && expiration_date < at
  end
end
