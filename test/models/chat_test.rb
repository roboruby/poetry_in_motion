require "test_helper"

class ChatTest < ActiveSupport::TestCase
  test "a new workspace binds the analyst model without a registry lookup" do
    chat = Analyst.start
    assert_equal Analyst::MODEL, chat.model_id
    assert_equal "openrouter", chat.provider
    assert_equal "New workspace", chat.display_title
  end

  test "surfaces replay from the event log in creation order" do
    chat = Analyst.start
    compose_filter_surface(chat)
    Workspace::Composer.new(chat).render(surface_id: "second", title: "Second",
                                         components: [ { "id" => "root", "component" => "Text", "text" => "hi" } ])
    assert_equal %w[customer-filter second], chat.surface_ids
    assert_equal [ "Filter customers", "Second" ], chat.tiles.map(&:heading)
    assert_equal "", chat.surface_session.surface("customer-filter").data["city"]
  end

  test "deleting a chat removes its events" do
    chat = Analyst.start
    compose_filter_surface(chat)
    assert_difference("UiEvent.count", -1) { chat.destroy! }
  end
end
