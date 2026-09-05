# A turn in the conversation. Every row is rendered by one partial
# (messages/_item) inside the chat's message scroller; rows are appended when
# they are created and morphed in place while the assistant streams.
class Message < ApplicationRecord
  acts_as_message
  has_many_attached :attachments

  # The prefix a surface action's user message carries, so the row renders
  # as an activity line and the agent knows the turn came from the UI.
  ACTION_PREFIX = "[ui action]".freeze

  after_create_commit :broadcast_appended
  after_update_commit :broadcast_settled
  after_destroy_commit :broadcast_removed

  scope :visible, -> { where.not(role: "system") }

  def dom_id_for_row
    "row-#{id}"
  end

  def user?
    role.to_s == "user"
  end

  def assistant?
    role.to_s == "assistant"
  end

  def tool_result?
    role.to_s == "tool"
  end

  def action?
    user? && content.to_s.start_with?(ACTION_PREFIX)
  end

  # An assistant row that has neither text nor tool calls yet: the agent is
  # still working on it (or it failed and is about to be destroyed).
  def pending?
    assistant? && content.blank? && output_tokens.nil? && tool_calls.none?
  end

  # Assistant text rendered as HTML (CommonMark, no raw HTML pass-through).
  def content_html
    Workspace::Markdown.render(content.to_s)
  end

  # The version stamped on the row for the client's versioned replace: the
  # settled render always outranks any streamed frame.
  def settled_version
    Workspace::Streamer::SETTLED_VERSION
  end

  private

  def broadcast_appended
    return if role.to_s == "system"

    Workspace::Streamer.new(chat).append_row(self)
  end

  def broadcast_settled
    return if role.to_s == "system"

    Workspace::Streamer.new(chat).replace_row(self, version: settled_version)
  end

  def broadcast_removed
    Workspace::Streamer.new(chat).remove_row(self)
  end
end
