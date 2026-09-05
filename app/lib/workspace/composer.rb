module Workspace
  # Applies A2UI messages to a chat's workspace: replays the event log into a
  # session, applies the new messages, renders the changed surfaces once to
  # collect Poetry's warnings, persists the accepted messages as ui_events,
  # and streams the changed tiles to the page. Rejected messages persist
  # nothing and come back as errors the agent can act on.
  class Composer
    Result = Struct.new(:ok, :surface_ids, :errors, :warnings, keyword_init: true) do
      def to_h
        if ok
          { ok: true, surfaces: surface_ids, warnings: warnings.presence }.compact
        else
          { ok: false, errors: errors, warnings: warnings.presence }.compact
        end
      end
    end

    # A component the catalog cannot render leaves a hole in the surface; the
    # agent gets the message back as an error and nothing persists.
    FATAL_WARNING = /unknown (basic catalog )?component/

    attr_reader :chat, :message

    # @param chat [Chat]
    # @param message [Message, nil] the assistant message the events belong to
    def initialize(chat, message: nil)
      @chat = chat
      @message = message
    end

    # Creates a surface, replacing one with the same id.
    def render(surface_id:, title:, components:, data: nil)
      data = resolve_references(data)
      surface_id = normalize_id(surface_id)
      return invalid("surface_id must be kebab-case (letters, digits, - or _)") unless Vocabulary::SURFACE_ID_PATTERN.match?(surface_id)

      messages = []
      messages << { "deleteSurface" => { "surfaceId" => surface_id } } if chat.surface_ids.include?(surface_id)
      messages << { "createSurface" => { "surfaceId" => surface_id, "catalogId" => Catalog::ID,
                                         "sendDataModel" => true, "dataModel" => data.is_a?(Hash) ? data : {},
                                         "components" => Array(components) } }
      apply(messages, title: plain(title))
    end

    # Upserts components and top-level data keys on an existing surface.
    def update(surface_id:, components: nil, data: nil, title: nil)
      data = resolve_references(data)
      surface_id = normalize_id(surface_id)
      return invalid("no surface #{surface_id.inspect}; render_surface creates one") unless chat.surface_ids.include?(surface_id)

      messages = []
      if components.is_a?(Array) && components.any?
        messages << { "updateComponents" => { "surfaceId" => surface_id, "components" => components } }
      end
      if data.is_a?(Hash)
        data.each { |key, value| messages << { "updateDataModel" => { "surfaceId" => surface_id, "path" => "/#{key}", "value" => value } } }
      end
      return invalid("nothing to update: pass components and/or data") if messages.empty?

      apply(messages, title: plain(title))
    end

    def remove(surface_id)
      surface_id = normalize_id(surface_id)
      return invalid("no surface #{surface_id.inspect}") unless chat.surface_ids.include?(surface_id)

      apply([ { "deleteSurface" => { "surfaceId" => surface_id } } ])
    end

    # @param messages [Array<Hash>] A2UI messages
    # @return [Result]
    def apply(messages, title: nil)
      messages = Array(messages).map { |entry| entry.deep_stringify_keys }
      session = chat.surface_session
      existing = session.surfaces.keys
      error_count = session.errors.size
      changed = session.apply_all(messages)
      errors = session.errors.drop(error_count).map { |entry| describe(entry["error"]) }
      return Result.new(ok: false, surface_ids: [], errors: errors, warnings: []) if errors.any?

      warnings = changed.flat_map { |id| (surface = session.surface(id)) ? render_warnings(surface) : [] }
      fatal = warnings.grep(FATAL_WARNING)
      return Result.new(ok: false, surface_ids: [], errors: fatal, warnings: warnings - fatal) if fatal.any?

      persist(messages, title)
      stream(session, changed, existing, recreated: messages.filter_map { |entry| entry.dig("createSurface", "surfaceId") })
      Result.new(ok: true, surface_ids: changed, errors: [], warnings: warnings)
    end

    # Resolves { "fromTool" => name, "key" => path } data references against
    # the latest result the named tool returned in this chat, so the agent
    # points at rows instead of retyping them. Unknown references resolve
    # to nil and the surface renders empty rather than failing.
    def resolve_references(data)
      return data unless data.is_a?(Hash)

      data.transform_values do |value|
        next value unless value.is_a?(Hash) && value["fromTool"].present?

        result = latest_tool_result(value["fromTool"].to_s)
        next nil if result.nil?

        value["key"].present? ? value["key"].to_s.split(".").reduce(result) { |node, key| node.is_a?(Hash) ? node[key] : nil } : result
      end
    end

    private

    def latest_tool_result(tool_name)
      message = chat.messages.joins(:parent_tool_call).where(role: "tool", tool_calls: { name: tool_name }).order(:id).last
      return nil unless message

      result = JSON.parse(message.content.to_s)
      result.is_a?(Hash) ? result : nil
    rescue JSON::ParserError
      nil
    end

    # Titles are plain text; a model that writes "&amp;" meant "&".
    def plain(title)
      title.present? ? CGI.unescapeHTML(title.to_s).strip : nil
    end

    # Ids are case-insensitive; the model tends to keep dataset ids uppercase.
    def normalize_id(surface_id)
      surface_id.to_s.strip.downcase
    end

    def invalid(text)
      Result.new(ok: false, surface_ids: [], errors: [ text ], warnings: [])
    end

    def describe(error)
      [ error["code"], error["path"], error["message"] ].compact.join(" ")
    end

    # Poetry refuses bad component calls quietly (the renderer warns and
    # renders nothing for them); the warnings go back to the agent.
    def render_warnings(surface)
      warnings = []
      ApplicationController.render(partial: "surfaces/validate", locals: { surface: surface, warnings: warnings })
      warnings
    end

    def persist(messages, title)
      chat.transaction do
        messages.each do |payload|
          event = UiEvent.from_message(payload, title: title)
          event.chat = chat
          event.message = message
          event.save!
        end
        chat.touch
      end
    end

    def stream(session, changed, existing, recreated:)
      streamer = Streamer.new(chat)
      tiles = chat.tiles(session).to_h { |tile| [ tile.id, tile ] }
      changed.each do |id|
        tile = tiles[id]
        if tile.nil?
          streamer.remove_tile(id)
        elsif !existing.include?(id)
          streamer.append_tile(tile)
        elsif recreated.include?(id)
          streamer.replace_tile(tile)
        else
          streamer.replace_surface(tile)
        end
      end
    end
  end
end
