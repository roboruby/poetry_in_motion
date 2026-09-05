require "test_helper"

class SurfaceToolsTest < ActiveSupport::TestCase
  setup { @chat = Analyst.start }

  test "tools carry the vocabulary schema" do
    schema = RenderSurfaceTool.new(@chat).params_schema
    assert_equal %w[surface_id title components], schema["required"]
    assert_includes schema.dig("properties", "components", "items", "properties", "component", "enum"), "Chart"
    assert_equal "render_surface", RenderSurfaceTool.new(@chat).name
  end

  test "render, update, and remove through the tool interface" do
    result = JSON.parse(RenderSurfaceTool.new(@chat).call({ "surface_id" => "note", "title" => "Note",
                                                             "components" => [ { "id" => "root", "component" => "Text", "text" => "**hi**" } ] }))
    assert_equal({ "ok" => true, "surfaces" => [ "note" ] }, result)
    result = JSON.parse(UpdateSurfaceTool.new(@chat).call({ "surface_id" => "note", "data" => { "rows" => [] } }))
    assert result["ok"]
    result = JSON.parse(RemoveSurfaceTool.new(@chat).call({ "surface_id" => "note" }))
    assert result["ok"]
    assert_empty @chat.reload.surface_ids
  end

  test "render errors reach the model as errors" do
    result = JSON.parse(RenderSurfaceTool.new(@chat).call({ "surface_id" => "note", "title" => "Note",
                                                             "components" => [ { "id" => "root", "component" => "Nope" } ] }))
    assert_equal false, result["ok"]
    assert_match(/unknown/, result["errors"].first)
  end

  test "the analyst prompt lists every component" do
    prompt = Analyst.instructions
    Workspace::Vocabulary.component_names.each { |name| assert_includes prompt, "- #{name}:" }
    assert_includes prompt, "2025-12-31"
  end
end
