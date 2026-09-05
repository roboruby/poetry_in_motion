require "test_helper"
require "turbo/broadcastable/test_helper"
require "minitest/mock"

class ChatResponseJobTest < ActiveJob::TestCase
  include Turbo::Broadcastable::TestHelper

  Chunk = Struct.new(:content, :tool_calls)

  def completion_writing(chat, text)
    lambda do |&block|
      row = chat.messages.create!(role: "assistant", content: "")
      text.split(" ").each { |word| block.call(Chunk.new("#{word} ", nil)) }
      row.update!(content: text, output_tokens: 3)
      row
    end
  end

  test "streams the assistant's text into its row and settles it" do
    chat = Analyst.start
    chat.create_user_message("Hello")

    streams = capture_turbo_stream_broadcasts(chat) do
      Chat.stub(:find, chat) do
        chat.stub(:complete, completion_writing(chat, "Hello analyst")) { ChatResponseJob.perform_now(chat.id) }
      end
    end

    appended = streams.find { |stream| stream["action"] == "append" && stream["target"] == "chat-messages" }
    assert appended, "assistant row appended"
    assert_includes appended.to_html, %(data-version="0"), "appended rows start at version 0"
    assert streams.any? { |stream| stream["action"] == "vreplace" && stream.to_html.include?("Hello analyst") }, "settled row replaced"
    assert streams.any? { |stream| stream["target"] == "chat-status" }, "status line updated"
  end

  test "a provider error surfaces in the chat after the retries" do
    chat = Analyst.start
    chat.create_user_message("Hello")
    attempts = 0
    failing = lambda do |&_block|
      attempts += 1
      raise RubyLLM::ServerError.new(nil, "upstream down")
    end

    streams = capture_turbo_stream_broadcasts(chat) do
      Chat.stub(:find, chat) do
        chat.stub(:complete, failing) { ChatResponseJob.perform_now(chat.id) }
      end
    end
    assert_equal ChatResponseJob::RETRIES + 1, attempts
    assert streams.any? { |stream| stream.to_html.include?("upstream down") }
  end

  test "a cut-off tool call is retried with a note and the placeholder is removed" do
    chat = Analyst.start
    chat.create_user_message("Hello")
    attempts = 0
    flaky = lambda do |&block|
      attempts += 1
      if attempts == 1
        chat.messages.create!(role: "assistant", content: "")
        raise Workspace::StreamCutOff.new(nil, "cut", finish_reason: "length", tool_name: "render_surface", bytes: 4058)
      end
      completion_writing(chat, "Second time works").call(&block)
    end

    streams = capture_turbo_stream_broadcasts(chat) do
      Chat.stub(:find, chat) do
        chat.stub(:complete, flaky) { ChatResponseJob.perform_now(chat.id) }
      end
    end
    assert_equal 2, attempts
    assert_equal [ "user", "assistant" ], chat.messages.reload.order(:id).pluck(:role), "the failed placeholder is gone"
    assert_equal "Second time works", chat.messages.last.content
    assert streams.none? { |stream| stream.to_html.include?("hit an error") }
    assert streams.any? { |stream| stream.to_html.include?("Retrying") }
  end
end
