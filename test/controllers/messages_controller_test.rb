require "test_helper"

class MessagesControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "a message persists at once and queues the analyst" do
    chat = Analyst.start
    assert_enqueued_with(job: ChatResponseJob, args: [ chat.id ]) do
      post chat_messages_path(chat), params: { message: { content: "Top merchants?" } }, as: :turbo_stream
    end
    assert_response :success
    assert_match(/turbo-stream action="replace" target="composer"/, response.body)
    assert_equal "Top merchants?", chat.messages.last.content
    assert_equal "Top merchants?", chat.reload.title
  end

  test "blank messages queue nothing" do
    chat = Analyst.start
    assert_no_enqueued_jobs do
      post chat_messages_path(chat), params: { message: { content: "  " } }, as: :turbo_stream
    end
  end
end
