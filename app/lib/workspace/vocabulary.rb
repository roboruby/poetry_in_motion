module Workspace
  # The component vocabulary the agent composes with, declared once and
  # reflected two ways: the prompt text the model reads and the JSON schema
  # the render tools accept. The Catalog renders the same names.
  module Vocabulary
    LAYOUT = { "children" => "[component ids] (required)", "justify" => "start|center|end|spaceBetween|spaceAround|spaceEvenly",
               "align" => "start|center|end|stretch" }.freeze

    COMPONENTS = {
      "Text" => { about: "Markdown text: headings, paragraphs, lists, bold, links.",
                  props: { "text" => "markdown string (required); ${/path} interpolates the data model",
                           "variant" => "\"caption\" for small muted text" } },
      "Grid" => { about: "Responsive grid; the first choice for laying out Stats and Cards.",
                  props: { "children" => "[component ids] (required)", "columns" => "1, 2, 3 or 4 (default 2)" } },
      "Row" => { about: "Horizontal flex row.", props: LAYOUT },
      "Column" => { about: "Vertical stack.", props: LAYOUT },
      "Card" => { about: "Bordered panel around one child (usually a Column).", props: { "child" => "component id (required)" } },
      "Tabs" => { about: "Tabbed panels.", props: { "tabs" => "[{ title: string, child: id }] (required)" } },
      "Divider" => { about: "A separator line.", props: { "axis" => "horizontal|vertical" } },
      "List" => { about: "Repeats children; with a template it renders one child per item of a bound array.",
                  props: { "children" => "[ids], or a template { componentId: id, path: \"/items\" } whose component uses relative bindings such as { path: \"name\" }",
                           "direction" => "vertical|horizontal" } },
      "Stat" => { about: "One KPI: a label over a big value, with an optional delta pill.",
                  props: { "label" => "string (required)", "value" => "formatted string such as \"$7.49B\" or \"50,000\" (required)",
                           "delta" => "change text such as \"+12.5%\"", "trend" => "up|down|flat",
                           "sentiment" => "positive|negative|neutral (color; set it when down is the good direction)",
                           "description" => "muted supporting copy" } },
      "Badge" => { about: "Small status pill.",
                   props: { "text" => "string (required)", "variant" => "default|secondary|destructive|outline|success|warning|info" } },
      "Table" => { about: "Data table; the first 50 rows render.",
                   props: { "columns" => "[{ key, label, align: \"start\"|\"end\", format: text|currency|number|integer|percent|date|datetime|badge, variants: { value: badgeVariant } }] (required)",
                            "rows" => "[objects keyed by column key] or a { path: \"/rows\" } binding into the data model (required)",
                            "caption" => "string", "maxHeight" => "true caps the height and pins the header" } },
      "Chart" => { about: "bar, line, area, pie or donut chart from row objects.",
                   props: { "kind" => "bar|line|area|pie|donut (required)", "data" => "[objects] or a { path } binding (required)",
                            "x" => "category key for bar/line/area (required there)",
                            "series" => "[{ key, label }] numeric keys to plot (required for bar/line/area)",
                            "nameKey" => "slice name key (pie/donut)", "valueKey" => "slice value key (pie/donut)",
                            "stacked" => "true stacks bar series", "horizontal" => "true for horizontal bars",
                            "height" => "pixels (default 280)", "label" => "accessible name and value label",
                            "centerLabel" => "donut hole title", "centerSubtitle" => "donut hole subtitle" } },
      "Metadata" => { about: "Key-value facts about one record (a customer, an account, a loan).",
                      props: { "items" => "[{ label, value, format }] or a { path } binding (required)",
                               "columns" => "one|two|three", "orientation" => "vertical|horizontal" } },
      "Empty" => { about: "Empty state when a query returns nothing.",
                   props: { "title" => "string", "description" => "string", "icon" => "lucide icon name such as search-x" } },
      "Button" => { about: "Action button; its child is a Text label. Pressing it sends the agent the event name and the resolved context as a new turn.",
                    props: { "child" => "id of a Text (required)", "variant" => "primary|default|borderless",
                             "action" => "{ event: { name: \"snake_case_event\", context: { key: literal or { path: \"/field\" } } } } (required)" } },
      "TextField" => { about: "Text input bound to the data model.",
                       props: { "label" => "string (required)", "value" => "{ path: \"/field\" } binding (required)",
                                "placeholder" => "string", "variant" => "shortText|longText|number|obscured",
                                "checks" => "[{ condition: { call: required|email|numeric|regex|length, args }, message }]" } },
      "CheckBox" => { about: "Boolean toggle bound to the data model.",
                      props: { "label" => "string (required)", "value" => "{ path } binding to a boolean (required)" } },
      "ChoicePicker" => { about: "Pick one or many options.",
                          props: { "label" => "string (required)", "options" => "[{ label, value }] (required)",
                                   "value" => "{ path } binding; the model holds an array of selected values (required)",
                                   "variant" => "\"multipleSelection\" for many", "displayStyle" => "\"chips\" for a wrapping row",
                                   "filterable" => "true for a searchable dropdown" } },
      "Slider" => { about: "Numeric range input.",
                    props: { "label" => "string", "value" => "{ path } binding to a number (required)", "min" => "number", "max" => "number", "steps" => "integer" } },
      "DateTimeInput" => { about: "Date (and time) input.",
                           props: { "label" => "string", "value" => "{ path } binding to an ISO date string (required)",
                                    "enableDate" => "true", "enableTime" => "true", "min" => "ISO date", "max" => "ISO date" } },
      "Icon" => { about: "A lucide icon.", props: { "name" => "lucide icon name (required)" } }
    }.freeze

    SURFACE_ID_PATTERN = /\A[a-z0-9][a-z0-9_-]{0,63}\z/

    COMPONENTS_SCHEMA = {
      "type" => "array",
      "description" => "Flat list of components. Exactly one has id \"root\"; parents reference children by id. Property names per component are listed in the instructions.",
      "items" => {
        "type" => "object",
        "properties" => {
          "id" => { "type" => "string", "description" => "Unique within the surface" },
          "component" => { "type" => "string", "enum" => COMPONENTS.keys }
        },
        "required" => %w[id component],
        "additionalProperties" => true
      }
    }.freeze

    DATA_SCHEMA = {
      "type" => "object",
      "description" => "The surface's data model: values components bind to with { path: \"/key\" } (table rows, chart data, filter fields).",
      "additionalProperties" => true
    }.freeze

    RENDER_SCHEMA = {
      "type" => "object",
      "properties" => {
        "surface_id" => { "type" => "string", "description" => "Stable kebab-case id such as overview-kpis or customer-CUS123" },
        "title" => { "type" => "string", "description" => "Short heading shown above the surface" },
        "components" => COMPONENTS_SCHEMA,
        "data" => DATA_SCHEMA
      },
      "required" => %w[surface_id title components],
      "additionalProperties" => false
    }.freeze

    UPDATE_SCHEMA = {
      "type" => "object",
      "properties" => {
        "surface_id" => { "type" => "string" },
        "title" => { "type" => "string", "description" => "New heading, when it changes" },
        "components" => COMPONENTS_SCHEMA.merge("description" => "Components to add or replace by id; untouched components stay"),
        "data" => DATA_SCHEMA.merge("description" => "Top-level keys to set in the data model; other keys stay")
      },
      "required" => %w[surface_id],
      "additionalProperties" => false
    }.freeze

    # The catalog as prompt text.
    #
    # @return [String]
    def self.prompt
      COMPONENTS.map do |name, spec|
        lines = [ "- #{name}: #{spec[:about]}" ]
        spec[:props].each { |prop, description| lines << "    #{prop}: #{description}" }
        lines.join("\n")
      end.join("\n")
    end

    def self.component_names
      COMPONENTS.keys
    end
  end
end
