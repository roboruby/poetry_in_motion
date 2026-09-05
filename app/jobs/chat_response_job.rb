# Runs one analyst turn: the user message is already persisted, so the job
# completes the conversation, streaming assistant text into its row and
# letting the tools stream surfaces onto the workspace as they run.
#
# A turn that dies on the provider's side (an error mid-stream, an overload,
# a tool call cut off before its JSON closed) is retried in place, with a
# note to the model when the cut came from its own output size.
class ChatResponseJob < ApplicationJob
  queue_as :default
  discard_on ActiveRecord::RecordNotFound

  RETRIES = 2
  BACKOFF = [ 2, 6 ].freeze
  RETRYABLE = [ Workspace::StreamCutOff, RubyLLM::ServerError, RubyLLM::ServiceUnavailableError,
                RubyLLM::OverloadedError, RubyLLM::RateLimitError ].freeze

  def perform(chat_id)
    chat = Chat.find(chat_id)
    streamer = Workspace::Streamer.new(chat)
    stream = Workspace::TextStream.new(chat, streamer)

    Analyst.prepare(chat)
    chat.before_message { stream.begin_message }
    chat.after_message { stream.end_message }
    chat.before_tool_call { |tool_call| streamer.status(status_for(tool_call)) }
    chat.after_tool_result { streamer.status("Composing") }

    attempt = 0
    begin
      streamer.status(attempt.zero? ? "Thinking" : "Retrying")
      chat.complete { |chunk| stream.push(chunk) }
    rescue *RETRYABLE => error
      Rails.logger.warn("ChatResponseJob #{chat_id}: attempt #{attempt + 1} #{error.class}: #{error.message}")
      discard_placeholder(chat)
      raise if attempt >= RETRIES

      chat.with_runtime_instructions(cut_off_note(error), append: true) if error.is_a?(Workspace::StreamCutOff)
      sleep(BACKOFF[attempt]) unless Rails.env.test?
      attempt += 1
      stream.end_message
      retry
    end
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
  # else leaves it behind.
  def discard_placeholder(chat)
    last = chat&.messages&.reload&.last
    last.destroy if last&.pending?
  end

  # What the model hears before the retry: keep the surface small.
  def cut_off_note(error)
    "Your previous #{error.tool_name || "tool"} call was cut off after #{error.bytes} bytes and never ran" \
    "#{" because the reply hit its output limit" if error.output_limit?}. Send it again, smaller: " \
    "point data at tool results with { fromTool, key } instead of retyping rows, keep the component list short, " \
    "and split a large screen into two surfaces."
  end

  def describe(error)
    case error
    when Workspace::StreamCutOff then "#{error.message}; the retries did not get through either. Ask again, or ask for less at once."
    when RubyLLM::Error then error.message
    else "#{error.class.name.demodulize.underscore.humanize}: #{error.message}".truncate(200)
    end
  end
end
