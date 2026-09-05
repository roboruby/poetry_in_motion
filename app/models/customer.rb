class Customer < ApplicationRecord
  include DatasetRecord

  # Credit score bands, highest first, as the dataset publishes them.
  CREDIT_BANDS = {
    "Excellent" => 750..,
    "Good" => 700..749,
    "Fair" => 650..699,
    "Poor" => 600..649,
    "Very poor" => ..599
  }.freeze

  has_many :accounts, dependent: :restrict_with_exception
  has_many :loans, dependent: :restrict_with_exception
  has_many :cards, through: :accounts
  has_many :transactions, through: :accounts

  scope :in_city, ->(city) { where("LOWER(city) = ?", city.to_s.downcase) }
  scope :named, ->(query) {
    term = "%#{sanitize_sql_like(query.to_s.strip)}%"
    where("first_name LIKE :q OR last_name LIKE :q OR (first_name || ' ' || last_name) LIKE :q OR email LIKE :q", q: term)
  }

  def full_name
    "#{first_name} #{last_name}"
  end

  def credit_band
    self.class.credit_band_for(credit_score)
  end

  def self.credit_band_for(score)
    return nil if score.nil?

    CREDIT_BANDS.find { |_name, range| range.cover?(score) }&.first
  end
end
