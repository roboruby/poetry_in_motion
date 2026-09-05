require "test_helper"

class SurfaceActionsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @chat = Analyst.start
    compose_filter_surface(@chat)
  end

  test "a button press becomes a user turn with the bound values" do
    assert_enqueued_with(job: ChatResponseJob) do
      post chat_surface_actions_path(@chat), params: { a2ui: { surface: "customer-filter", action: "go", values: { "/city" => "London" } } }
    end
    assert_response :success
    assert_match(/vreplace/, response.body)
    message = @chat.messages.last
    assert message.action?
    assert_includes message.content, "filter_customers"
    assert_includes message.content, '"city":"London"'
    assert_equal "London", @chat.surface_session.surface("customer-filter").data["city"]
    assert_equal "updateDataModel", @chat.ui_events.in_order.last.kind
  end

  test "a failed check re-renders with the error and no turn" do
    assert_no_enqueued_jobs do
      post chat_surface_actions_path(@chat), params: { a2ui: { surface: "customer-filter", action: "go", values: { "/city" => "" } } }
    end
    assert_response :unprocessable_content
    assert_includes response.body, "City is required"
  end

  test "unknown surfaces answer 422" do
    post chat_surface_actions_path(@chat), params: { a2ui: { surface: "ghost", action: "go" } }
    assert_response :unprocessable_content
  end

  test "closing a tile removes the surface without a turn" do
    assert_no_enqueued_jobs do
      delete chat_surface_path(@chat, surface_id: "customer-filter"), as: :turbo_stream
    end
    assert_response :success
    assert_empty @chat.surface_ids
  end
end
