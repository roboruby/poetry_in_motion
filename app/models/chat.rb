# A chat is a workspace: the conversation with the analyst agent plus the
# surfaces the agent composed while talking. Surfaces are not stored as HTML;
# the chat keeps the A2UI message log (ui_events) and replays it.
class Chat < ApplicationRecord
  acts_as_chat

  has_many :ui_events, dependent: :destroy

  after_initialize { self.assume_model_exists = true }

  scope :recent, -> { order(updated_at: :desc) }

  def display_title
    title.presence || first_prompt&.truncate(60) || "New workspace"
  end

  def first_prompt
    messages.where(role: "user").order(:id).pick(:content)
  end

  # The A2UI session rebuilt from the event log.
  #
  # @return [Poetry::Agent::A2UI::Session]
  def surface_session
    Workspace::Catalog.session.tap { |session| session.apply_all(ui_events.in_order.map(&:payload)) }
  end

  # Live surfaces in creation order, with the title the agent gave each one.
  #
  # @return [Array<Workspace::Tile>]
  def tiles(session = surface_session)
    titles = ui_events.where.not(title: nil).in_order.to_h { |event| [ event.surface_id, event.title ] }
    session.surfaces.values.map { |surface| Workspace::Tile.new(surface: surface, title: titles[surface.id]) }
  end

  def surface_ids
    surface_session.surfaces.keys
  end
end
