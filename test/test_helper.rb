ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # A workspace with one surface: a bound city field and a button that
    # sends an event with that field's value.
    def compose_filter_surface(chat)
      Workspace::Composer.new(chat).render(
        surface_id: "customer-filter", title: "Filter customers",
        components: [
          { "id" => "root", "component" => "Column", "children" => %w[city go] },
          { "id" => "city", "component" => "TextField", "label" => "City", "value" => { "path" => "/city" },
            "checks" => [ { "condition" => { "call" => "required", "args" => { "value" => { "path" => "/city" } } }, "message" => "City is required" } ] },
          { "id" => "go", "component" => "Button", "variant" => "primary", "child" => "go_label",
            "action" => { "event" => { "name" => "filter_customers", "context" => { "city" => { "path" => "/city" } } } } },
          { "id" => "go_label", "component" => "Text", "text" => "Filter" }
        ],
        data: { "city" => "" }
      )
    end
  end
end
