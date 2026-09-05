require "application_system_test_case"

# The workspace's two shapes, rendered in a real browser: the chat center
# stage on an empty canvas, and docked to the corner once a surface exists.
class WorkspaceTest < ApplicationSystemTestCase
  test "a new workspace opens with the chat center stage" do
    chat = Analyst.start
    visit chat_path(chat)

    assert_selector "[data-controller=workspace][data-state=hero]"
    assert_text "What do you want to see?"
    assert_button "Give me an overview of the bank"
    assert_selector "textarea[name='message[content]']"
  end

  test "a workspace with a surface docks the chat and renders the surface" do
    chat = Analyst.start(title: "Loans")
    compose_filter_surface(chat)
    visit chat_path(chat)

    assert_selector "[data-controller=workspace][data-state=docked]"
    assert_selector "[data-surface-tile=customer-filter]"
    assert_field "City"
    assert_button "Filter"
    click_button "Minimize chat"
    assert_selector "[data-controller=workspace][data-state=minimized]"
  end
end
