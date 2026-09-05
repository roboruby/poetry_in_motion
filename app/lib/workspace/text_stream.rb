module Workspace
  # Streams the assistant's text into its chat row while the model writes:
  # the row is morphed with the accumulated text a few times per second
  # (never one node per token), each frame carrying a rising version. The
  # settled row, written when the message persists, outranks every frame.
  class TextStream
    INTERVAL = 0.15

    attr_reader :chat, :streamer

    def initialize(chat, streamer = Streamer.new(chat))
      @chat = chat
      @streamer = streamer
      @buffer = +""
      @version = 0
      @flushed_at = 0.0
      @message = nil
    end

    # Called when the model starts a new assistant message.
    def begin_message
      @message = Message.where(chat_id: chat.id, role: "assistant").order(:id).last
      @buffer = +""
      @version = 0
    end

    def push(chunk)
      streamer.status("Looking things up") if chunk.tool_calls.present?
      text = chunk.content.to_s
      return if text.empty?

      begin_message if @message.nil?
      @buffer << text
      flush if now - @flushed_at > INTERVAL
    end

    def end_message
      @message = nil
      @buffer = +""
    end

    private

    def flush
      return if @message.nil? || @buffer.empty?

      @version += 1
      @flushed_at = now
      streamer.replace_row(@message, version: @version, streamed: @buffer.dup)
    end

    def now
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
