require "test_helper"

class ChatsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "index lists workspaces" do
    Analyst.start(title: "Loans review")
    get root_path
    assert_response :success
    assert_select "a", text: "Loans review"
  end

  test "create opens a workspace and asks the first question" do
    assert_enqueued_with(job: ChatResponseJob) do
      post chats_path, params: { prompt: "Overview please" }
    end
    chat = Chat.last
    assert_redirected_to chat
    assert_equal "Overview please", chat.messages.last.content
    assert_equal "Overview please", chat.display_title
  end

  test "show renders the hero state on an empty workspace and docks once surfaces exist" do
    chat = Analyst.start
    get chat_path(chat)
    assert_response :success
    assert_select "[data-state=hero]"
    assert_select "#surfaces"

    compose_filter_surface(chat)
    get chat_path(chat)
    assert_select "[data-state=docked]"
    assert_select "[data-surface-tile=customer-filter]"
    assert_select "button[name='a2ui[action]'][value=go]"
  end

  test "destroy removes the workspace" do
    chat = Analyst.start
    delete chat_path(chat)
    assert_redirected_to root_path
    assert_nil Chat.find_by(id: chat.id)
  end
end
