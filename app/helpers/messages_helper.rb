module MessagesHelper
  TOOL_LABELS = {
    "bank_overview" => "Pulled the bank overview", "search_customers" => "Searched customers",
    "customer_profile" => "Opened a customer profile", "transactions" => "Listed transactions",
    "aggregate" => "Aggregated", "loans" => "Listed loans", "merchants" => "Ranked merchants",
    "branches" => "Listed branches", "render_surface" => "Composed a surface",
    "update_surface" => "Updated a surface", "remove_surface" => "Removed a surface"
  }.freeze

  ARGUMENT_HINTS = %w[query customer_id metric group_by surface_id title city].freeze

  # "Aggregated · transaction_volume by month"
  def tool_call_label(tool_call)
    name = tool_call.name.to_s
    label = TOOL_LABELS.fetch(name) { name.humanize }
    arguments = tool_call.arguments.is_a?(Hash) ? tool_call.arguments : {}
    hint = case name
    when "aggregate" then [ arguments["metric"], arguments["group_by"] && "by #{arguments["group_by"]}" ].compact.join(" ")
    when "render_surface", "update_surface", "remove_surface" then arguments["title"] || arguments["surface_id"]
    else ARGUMENT_HINTS.filter_map { |key| arguments[key] }.first
    end
    hint.present? ? "#{label} · #{hint}" : label
  end

  # The short outcome of a tool result row.
  def tool_result_label(message)
    name = message.parent_tool_call&.name.to_s
    result = parse_result(message)
    return "#{name.humanize} answered" unless result
    return "#{name.humanize} failed: #{result["error"]}" if result["error"]

    if result.key?("ok")
      result["ok"] ? "Surface ready#{" with warnings" if result["warnings"]}" : "Surface rejected: #{Array(result["errors"]).first}"
    elsif result["returned"]
      "#{pluralize(result["returned"], "row")}#{" of #{result["total_matches"]}" if result["total_matches"]}"
    elsif result["rows"]
      pluralize(Array(result["rows"]).size, "group")
    elsif result.key?("total")
      "One total"
    elsif name == "bank_overview"
      "Bank totals loaded"
    elsif name == "customer_profile"
      "Profile loaded"
    else
      "Done"
    end
  end

  def tool_result_failed?(message)
    result = parse_result(message)
    result.present? && (result["error"].present? || result["ok"] == false)
  end

  # "[ui action] view_transactions on customer-x: {...}" => "View transactions"
  def action_label(message)
    body = message.content.to_s.delete_prefix(Message::ACTION_PREFIX).strip
    name = body.split(" on ", 2).first.to_s
    name.humanize.presence || "Action"
  end

  private

  def parse_result(message)
    result = JSON.parse(message.content.to_s)
    result.is_a?(Hash) ? result : nil
  rescue JSON::ParserError
    nil
  end
end
