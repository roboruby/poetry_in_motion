# Rows imported from the synthetic banking dataset are reference data: the
# app reads them and never writes them, so every dataset model is read-only
# and keeps the dataset's own timestamps (Rails never stamps them).
module DatasetRecord
  extend ActiveSupport::Concern

  included do
    self.record_timestamps = false
  end

  def readonly?
    true
  end
end
