require "test_helper"

class Workspace::ComposerTest < ActiveSupport::TestCase
  setup { @chat = Analyst.start }

  test "render persists events and reports the surface" do
    result = compose_filter_surface(@chat)
    assert result.ok, result.errors.inspect
    assert_equal [ "customer-filter" ], result.surface_ids
    assert_equal %w[createSurface], @chat.ui_events.pluck(:kind)
    assert_equal "Filter customers", @chat.ui_events.first.title
  end

  test "rendering an existing id replaces it" do
    compose_filter_surface(@chat)
    result = Workspace::Composer.new(@chat).render(surface_id: "customer-filter", title: "Again",
                                                   components: [ { "id" => "root", "component" => "Text", "text" => "again" } ])
    assert result.ok
    assert_equal %w[createSurface deleteSurface createSurface], @chat.ui_events.in_order.pluck(:kind)
    assert_equal [ "Again" ], @chat.tiles.map(&:heading)
  end

  test "unknown components are rejected and nothing persists" do
    result = Workspace::Composer.new(@chat).render(surface_id: "x", title: "X", components: [ { "id" => "root", "component" => "Hologram" } ])
    assert_not result.ok
    assert_match(/unknown/, result.errors.first)
    assert_equal 0, @chat.ui_events.count
  end

  test "session errors come back as errors" do
    result = Workspace::Composer.new(@chat).render(surface_id: "x", title: "X", components: [ { "id" => "root", "component" => "Card", "child" => "root" } ])
    assert_not result.ok
    assert_match(/circular/, result.errors.first)
  end

  test "bad surface ids are refused" do
    result = Workspace::Composer.new(@chat).render(surface_id: "Not Valid!", title: "X", components: [])
    assert_not result.ok
  end

  test "update merges data and components on an existing surface" do
    compose_filter_surface(@chat)
    result = Workspace::Composer.new(@chat).update(surface_id: "customer-filter", data: { "city" => "London" },
                                                   components: [ { "id" => "go_label", "component" => "Text", "text" => "Go" } ], title: "Renamed")
    assert result.ok, result.errors.inspect
    surface = @chat.surface_session.surface("customer-filter")
    assert_equal "London", surface.data["city"]
    assert_equal "Go", surface.component("go_label")["text"]
    assert_equal [ "Renamed" ], @chat.tiles.map(&:heading)
  end

  test "update of a missing surface fails" do
    assert_not Workspace::Composer.new(@chat).update(surface_id: "nope", data: { "a" => 1 }).ok
  end

  test "remove deletes the surface" do
    compose_filter_surface(@chat)
    assert Workspace::Composer.new(@chat).remove("customer-filter").ok
    assert_empty @chat.surface_ids
  end
end
