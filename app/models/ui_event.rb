# One A2UI message the agent (or a surface action) applied to a chat's
# workspace. The chat replays its events in order to rebuild the surfaces;
# nothing else stores UI state.
class UiEvent < ApplicationRecord
  KINDS = %w[createSurface updateComponents updateDataModel deleteSurface].freeze

  belongs_to :chat
  belongs_to :message, optional: true

  validates :kind, inclusion: { in: KINDS }
  validates :surface_id, presence: true

  scope :in_order, -> { order(:id) }

  # @param payload [Hash] an A2UI message (`{ "createSurface" => {...} }` etc.)
  def self.from_message(payload, title: nil)
    kind = (KINDS & payload.keys).first or raise ArgumentError, "not an A2UI message: #{payload.keys}"
    new(kind: kind, surface_id: payload.dig(kind, "surfaceId").to_s, title: title, payload: payload)
  end
end
