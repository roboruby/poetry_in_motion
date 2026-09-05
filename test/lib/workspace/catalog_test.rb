require "test_helper"

class Workspace::CatalogTest < ActiveSupport::TestCase
  def render(components, data: {})
    session = Workspace::Catalog.session
    session.apply({ "createSurface" => { "surfaceId" => "t", "catalogId" => Workspace::Catalog::ID,
                                         "dataModel" => data, "components" => components } })
    assert_empty session.errors
    warnings = []
    html = ApplicationController.render(partial: "surfaces/validate", locals: { surface: session.surface("t"), warnings: warnings })
    [ html, warnings ]
  end

  test "grid and stats" do
    html, warnings = render([
      { "id" => "root", "component" => "Grid", "columns" => 3, "children" => %w[a b] },
      { "id" => "a", "component" => "Stat", "label" => "Customers", "value" => "50,000", "delta" => "+2%", "trend" => "up" },
      { "id" => "b", "component" => "Stat", "label" => "Churn", "value" => "2.1%", "trend" => "down", "sentiment" => "positive", "description" => "down is good" }
    ])
    assert_empty warnings
    assert_includes html, "xl:grid-cols-3"
    assert_equal 2, html.scan('data-slot="stat"').size
    assert_includes html, "down is good"
  end

  test "table formats cells and renders badges" do
    html, warnings = render([
      { "id" => "root", "component" => "Table", "caption" => "Accounts",
        "columns" => [ { "key" => "type", "label" => "Type" }, { "key" => "balance", "label" => "Balance", "format" => "currency", "align" => "end" },
                       { "key" => "status", "label" => "Status", "format" => "badge", "variants" => { "Open" => "success" } } ],
        "rows" => { "path" => "/rows" } }
    ], data: { "rows" => [ { "type" => "Checking", "balance" => 1234.5, "status" => "Open" } ] })
    assert_empty warnings
    assert_includes html, "$1,234.50"
    assert_includes html, "text-right"
    assert_includes html, 'data-slot="badge"'
    assert_includes html, "Accounts"
  end

  test "bar, line, and donut charts render SVG from row objects" do
    html, warnings = render([
      { "id" => "root", "component" => "Column", "children" => %w[bar line pie] },
      { "id" => "bar", "component" => "Chart", "kind" => "bar", "x" => "month", "series" => [ { "key" => "volume", "label" => "Volume" } ],
        "data" => [ { "month" => "Jan", "volume" => 10 }, { "month" => "Feb", "volume" => "12.5" } ], "stacked" => true },
      { "id" => "line", "component" => "Chart", "kind" => "line", "x" => "month", "series" => [ { "key" => "a" }, { "key" => "b" } ],
        "data" => [ { "month" => "Jan", "a" => 1, "b" => 2 } ] },
      { "id" => "pie", "component" => "Chart", "kind" => "donut", "nameKey" => "band", "valueKey" => "n", "centerLabel" => "2",
        "data" => [ { "band" => "Very poor", "n" => 1 }, { "band" => "Good", "n" => 1 } ] }
    ])
    assert_empty warnings
    assert_operator html.scan("<svg").size, :>=, 3
    assert_includes html, "Very poor"
  end

  test "chart without series warns instead of raising" do
    _html, warnings = render([ { "id" => "root", "component" => "Chart", "kind" => "bar", "data" => [ { "x" => 1 } ] } ])
    assert_match(/x and series/, warnings.first)
  end

  test "metadata, empty, and badge" do
    html, warnings = render([
      { "id" => "root", "component" => "Column", "children" => %w[m e b] },
      { "id" => "m", "component" => "Metadata", "columns" => "two", "items" => [ { "label" => "Opened", "value" => "2024-02-15", "format" => "date" } ] },
      { "id" => "e", "component" => "Empty", "title" => "No loans", "description" => "Nothing matched", "icon" => "search-x" },
      { "id" => "b", "component" => "Badge", "text" => "Active", "variant" => "success" }
    ])
    assert_empty warnings
    assert_includes html, "Feb 15, 2024"
    assert_includes html, "No loans"
    assert_includes html, "Active"
  end

  test "date input gets a visible label" do
    html, warnings = render([ { "id" => "root", "component" => "DateTimeInput", "label" => "From", "value" => { "path" => "/from" }, "enableDate" => true } ],
                            data: { "from" => "2025-01-01" })
    assert_empty warnings
    assert_includes html, "From"
    assert_includes html, 'type="date"'
  end

  test "unknown components warn" do
    _html, warnings = render([ { "id" => "root", "component" => "Hologram" } ])
    assert_match(/unknown basic catalog component/, warnings.first)
  end
end
