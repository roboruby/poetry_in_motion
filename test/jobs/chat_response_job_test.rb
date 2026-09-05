require "test_helper"
require "minitest/mock"
require "turbo/broadcastable/test_helper"

class ChatResponseJobTest < ActiveJob::TestCase
  include Turbo::Broadcastable::TestHelper

  Chunk = Struct.new(:content, :tool_calls)

  test "streams the assistant's text into its row and settles it" do
    chat = Analyst.start
    chat.create_user_message("Hello")
    completion = lambda do |&block|
      row = chat.messages.create!(role: "assistant", content: "")
      block.call(Chunk.new("Hello ", nil))
      block.call(Chunk.new("analyst", nil))
      row.update!(content: "Hello analyst", output_tokens: 3)
      row
    end

    streams = capture_turbo_stream_broadcasts(chat) do
      Chat.stub(:find, chat) do
        chat.stub(:complete, completion) { ChatResponseJob.perform_now(chat.id) }
      end
    end

    assert streams.any? { |stream| stream["action"] == "append" && stream["target"] == "chat-messages" }, "assistant row appended"
    assert streams.any? { |stream| stream["action"] == "vreplace" && stream.to_html.include?("Hello analyst") }, "settled row replaced"
    assert streams.any? { |stream| stream["target"] == "chat-status" }, "status line updated"
  end

  test "a provider error surfaces in the chat" do
    chat = Analyst.start
    chat.create_user_message("Hello")
    failing = lambda { |&_block| raise RubyLLM::ServerError.new(nil, "upstream down") }

    streams = capture_turbo_stream_broadcasts(chat) do
      Chat.stub(:find, chat) do
        chat.stub(:complete, failing) { ChatResponseJob.perform_now(chat.id) }
      end
    end
    assert streams.any? { |stream| stream.to_html.include?("upstream down") }
  end
end
