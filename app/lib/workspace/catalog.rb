module Workspace
  # The workspace's A2UI catalog: the spec's basic catalog (text, layout,
  # forms, buttons) rendered as Poetry components by poetry-agent, extended
  # with the data components an operations console needs: Grid, Stat, Badge,
  # Table, Chart, Metadata, and Empty. Every extension renders a Poetry
  # component; nothing here writes raw markup beyond a grid wrapper.
  class Catalog < Poetry::Agent::A2UI::Catalogs::Basic
    ID = "https://poetryui.com/a2ui/poetry_in_motion/catalog.json"
    EXTRA_COMPONENTS = %w[Grid Stat Badge Table Chart Metadata Empty].freeze

    GRID_COLUMNS = {
      "1" => "grid grid-cols-1 gap-4",
      "2" => "grid grid-cols-1 gap-4 md:grid-cols-2",
      "3" => "grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-3",
      "4" => "grid grid-cols-2 gap-4 xl:grid-cols-4"
    }.freeze
    CHART_COLORS = %w[var(--chart-1) var(--chart-2) var(--chart-3) var(--chart-4) var(--chart-5)].freeze
    CHART_KINDS = %w[bar line area pie donut].freeze
    BADGE_VARIANTS = %w[default secondary destructive outline success warning info].freeze
    STAT_TRENDS = %w[up down flat].freeze
    STAT_SENTIMENTS = %w[positive negative neutral].freeze
    TABLE_ROW_LIMIT = 50
    CHART_ROW_LIMIT = 60

    # A session whose every catalog id resolves to this catalog, so a model
    # that names the basic catalog (or none) still gets the extensions.
    #
    # @return [Poetry::Agent::A2UI::Session]
    def self.session
      catalog = new
      Poetry::Agent::A2UI::Session.new(
        catalogs: { ID => catalog, Poetry::Agent::A2UI::Catalogs::Basic::ID => catalog },
        default_catalog: catalog
      )
    end

    def id
      ID
    end

    def references(component)
      component["component"] == "Grid" ? [ component["children"] ].compact : super
    end

    private

    def render_grid(component, scope, renderer)
      classes = GRID_COLUMNS.fetch(component["columns"].to_s, GRID_COLUMNS["2"])
      renderer.view.tag.div(renderer.render_children(component["children"], scope), class: classes)
    end

    def render_stat(component, scope, renderer)
      attributes = { label: renderer.text(component["label"], scope).presence || "Metric" }
      delta = renderer.text(component["delta"], scope)
      attributes[:delta] = delta if delta.present?
      trend = component["trend"].to_s
      attributes[:trend] = trend.to_sym if STAT_TRENDS.include?(trend)
      sentiment = component["sentiment"].to_s
      attributes[:sentiment] = sentiment.to_sym if STAT_SENTIMENTS.include?(sentiment)
      description = renderer.text(component["description"], scope)
      value = renderer.text(component["value"], scope)

      renderer.component(Poetry::Ui::Stat::Component, attributes) do |stat|
        stat.with_description { description } if description.present?
        value
      end
    end

    def render_badge(component, scope, renderer)
      text = renderer.text(component["text"], scope)
      return renderer.blank if text.empty?

      variant = component["variant"].to_s
      attributes = { variant: BADGE_VARIANTS.include?(variant) ? variant.to_sym : :secondary }
      renderer.component(Poetry::Ui::Badge::Component, attributes) { text }
    end

    def render_table(component, scope, renderer)
      columns = Array(component["columns"]).grep(Hash).select { |column| column["key"].present? }
      return renderer.warn("Table #{component["id"].inspect}: columns must list { key, label }") if columns.empty?

      rows = Array(renderer.resolve(component["rows"], scope)).grep(Hash)
      view = renderer.view
      shown = rows.first(TABLE_ROW_LIMIT)
      caption = renderer.text(component["caption"], scope)
      caption = "#{caption.presence || "Rows"} (first #{TABLE_ROW_LIMIT} of #{rows.size})" if rows.size > TABLE_ROW_LIMIT
      attributes = {}
      if component["maxHeight"].present?
        attributes = { sticky_header: true, container_class: "max-h-96",
                       scroll_label: caption.presence || "Table" }
      end

      renderer.component(Poetry::Ui::Table::Component, attributes) do
        parts = []
        parts << view.poetry_table_caption { caption } if caption.present?
        parts << view.poetry_table_header do
          view.poetry_table_row do
            view.safe_join(columns.map do |column|
              view.poetry_table_head(class: align_class(column)) { column["label"].to_s.presence || column["key"].to_s.humanize }
            end)
          end
        end
        parts << view.poetry_table_body do
          if shown.empty?
            view.poetry_table_row do
              view.poetry_table_cell(colspan: columns.size, class: "text-muted-foreground") { "No rows" }
            end
          else
            view.safe_join(shown.map do |row|
              view.poetry_table_row do
                view.safe_join(columns.map do |column|
                  view.poetry_table_cell(class: align_class(column)) { table_cell(row, column, renderer) }
                end)
              end
            end)
          end
        end
        view.safe_join(parts)
      end
    end

    def align_class(column)
      column["align"].to_s == "end" ? "text-right" : nil
    end

    def table_cell(row, column, renderer)
      raw = row[column["key"].to_s]
      case column["format"].to_s
      when "badge"
        return "" if raw.nil?

        variants = column["variants"].is_a?(Hash) ? column["variants"] : {}
        variant = variants[raw.to_s].to_s
        renderer.component(Poetry::Ui::Badge::Component,
                           { variant: BADGE_VARIANTS.include?(variant) ? variant.to_sym : :secondary },
                           suffix: "#{column["key"]}-#{raw}") { raw.to_s }
      else
        Format.value(raw, column["format"])
      end
    end

    def render_chart(component, scope, renderer)
      kind = component["kind"].to_s
      kind = "bar" unless CHART_KINDS.include?(kind)
      rows = Array(renderer.resolve(component["data"], scope)).grep(Hash).first(CHART_ROW_LIMIT)
      return renderer.warn("Chart #{component["id"].inspect}: data must be a non-empty array of objects") if rows.empty?

      chart_id = "chart-#{renderer.surface.id}-#{component["id"]}".parameterize
      height = component["height"].to_i.clamp(160, 600)
      height = 280 if component["height"].blank?

      if %w[pie donut].include?(kind)
        render_pie(component, rows, renderer, chart_id: chart_id, height: height, donut: kind == "donut")
      else
        render_xy(component, rows, renderer, kind: kind, chart_id: chart_id, height: height)
      end
    end

    def render_xy(component, rows, renderer, kind:, chart_id:, height:)
      x = component["x"].to_s
      series = Array(component["series"]).grep(Hash).select { |entry| entry["key"].present? }
      if x.empty? || series.empty?
        return renderer.warn("Chart #{component["id"].inspect}: x and series[{ key, label }] are required")
      end

      config = series.each_with_index.to_h do |entry, index|
        [ entry["key"].to_sym, { label: entry["label"].presence || entry["key"].to_s.humanize,
                                 color: CHART_COLORS[index % CHART_COLORS.size] } ]
      end
      data = rows.map do |row|
        point = { x.to_sym => row[x].to_s }
        series.each { |entry| point[entry["key"].to_sym] = Format.numeric(row[entry["key"]] || 0) }
        point
      end
      klass, mark = case kind
      when "line" then [ Poetry::Charts::LineChart::Component, :with_line ]
      when "area" then [ Poetry::Charts::AreaChart::Component, :with_area ]
      else [ Poetry::Charts::BarChart::Component, :with_bar ]
      end
      horizontal = kind == "bar" && component["horizontal"] == true
      attributes = { data: data, config: config, id: chart_id, height: height }
      attributes[:orientation] = :horizontal if horizontal
      attributes[:label] = component["label"].to_s if component["label"].present?

      renderer.component(klass, attributes) do |chart|
        chart.with_grid
        if horizontal
          chart.with_y_axis(data_key: x.to_sym)
        else
          chart.with_x_axis(data_key: x.to_sym)
        end
        series.each do |entry|
          options = { data_key: entry["key"].to_sym }
          options[:stack] = :stack if component["stacked"] == true && kind == "bar"
          options[:radius] = 4 if kind == "bar"
          chart.public_send(mark, **options)
        end
        chart.with_tooltip
        chart.with_legend if series.size > 1
        nil
      end
    end

    def render_pie(component, rows, renderer, chart_id:, height:, donut:)
      name_key = component["nameKey"].to_s
      value_key = component["valueKey"].to_s
      if name_key.empty? || value_key.empty?
        return renderer.warn("Chart #{component["id"].inspect}: pie charts need nameKey and valueKey")
      end

      slugs = {}
      slices = rows.each_with_index.map do |row, index|
        name = row[name_key].to_s
        slug = name.parameterize(separator: "_").presence || "slice"
        slug = "#{slug}_#{index}" if slugs.key?(slug)
        slugs[slug] = name
        { slug: slug, name: name, value: Format.numeric(row[value_key] || 0), index: index }
      end
      config = { value: { label: component["label"].presence || value_key.humanize } }
      slices.each do |slice|
        config[slice[:slug].to_sym] = { label: slice[:name], color: CHART_COLORS[slice[:index] % CHART_COLORS.size] }
      end
      data = slices.map { |slice| { name: slice[:slug], value: slice[:value], fill: "var(--color-#{slice[:slug]})" } }

      renderer.component(Poetry::Charts::PieChart::Component, data: data, config: config, id: chart_id, height: height) do |chart|
        options = { data_key: :value, name_key: :name }
        options[:inner_radius] = 60 if donut
        chart.with_pie(**options)
        if donut && component["centerLabel"].present?
          chart.with_center_label(title: renderer.text(component["centerLabel"]), subtitle: renderer.text(component["centerSubtitle"]).presence)
        end
        chart.with_tooltip
        chart.with_legend
        nil
      end
    end

    def render_metadata(component, scope, renderer)
      items = Array(renderer.resolve(component["items"], scope)).grep(Hash)
      return renderer.warn("Metadata #{component["id"].inspect}: items must list { label, value }") if items.empty?

      attributes = {}
      columns = component["columns"].to_s
      attributes[:columns] = columns.to_sym if %w[one two three].include?(columns)
      orientation = component["orientation"].to_s
      attributes[:orientation] = orientation.to_sym if %w[vertical horizontal].include?(orientation)

      renderer.component(Poetry::Ui::MetadataList::Component, attributes) do |list|
        items.each do |item|
          list.with_item(label: item["label"].to_s) { Format.value(item["value"], item["format"]) }
        end
        nil
      end
    end

# The basic catalog renders a date input without a visible label; a
# console needs the label, so the control gets Poetry's Field around it.
def render_date_time_input(component, scope, renderer)
  control = super
  label = renderer.text(component["label"], scope)
  return control if label.empty?

  renderer.component(Poetry::Ui::Field::Component,
                     { id: renderer.control_id(component, scope), label_text: label }, suffix: "field") { control }
end

    def render_empty(component, scope, renderer)
      title = renderer.text(component["title"], scope)
      description = renderer.text(component["description"], scope)
      icon = component["icon"].to_s

      renderer.component(Poetry::Ui::Empty::Component) do |empty|
        if icon.present?
          empty.with_media { renderer.view.render(Poetry::Ui::Icon::Component.new(name: icon_name(icon))) }
        end
        empty.with_title { title.presence || "Nothing here" }
        empty.with_description { description } if description.present?
        nil
      end
    end
  end
end
