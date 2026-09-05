# Runs one analyst turn: the user message is already persisted, so the job
# completes the conversation, streaming assistant text into its row and
# letting the tools stream surfaces onto the workspace as they run.
class ChatResponseJob < ApplicationJob
  queue_as :default
  discard_on ActiveRecord::RecordNotFound

  def perform(chat_id)
    chat = Chat.find(chat_id)
    streamer = Workspace::Streamer.new(chat)
    stream = Workspace::TextStream.new(chat, streamer)

    Analyst.prepare(chat)
    chat.before_message { stream.begin_message }
    chat.after_message { stream.end_message }
    chat.before_tool_call { |tool_call| streamer.status(status_for(tool_call)) }
    chat.after_tool_result { streamer.status("Composing") }

    streamer.status("Thinking")
    chat.complete { |chunk| stream.push(chunk) }
  rescue StandardError => error
    Rails.logger.error("ChatResponseJob #{chat_id}: #{error.class}: #{error.message}")
    discard_placeholder(chat)
    streamer&.error(describe(error))
  ensure
    streamer&.clear_status
  end

  private

  def status_for(tool_call)
    case tool_call.name.to_s
    when "render_surface", "update_surface", "remove_surface" then "Composing the workspace"
    else "Querying #{tool_call.name.to_s.humanize.downcase}"
    end
  end

  # RubyLLM removes its empty assistant row on provider errors; anything
  # else (a truncated tool call that fails to parse) leaves it behind.
  def discard_placeholder(chat)
    last = chat&.messages&.reload&.last
    last.destroy if last&.pending?
  end

  def describe(error)
    case error
    when JSON::ParserError then "the model's reply was cut off before it finished (try a smaller surface or ask again)"
    when RubyLLM::Error then error.message
    else "#{error.class.name.demodulize.underscore.humanize}: #{error.message}".truncate(200)
    end
  end
end
