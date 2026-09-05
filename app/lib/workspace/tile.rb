module Workspace
  # A surface on the workspace with the title the agent gave it.
  Tile = Struct.new(:surface, :title, keyword_init: true) do
    def id
      surface.id
    end

    def dom_id
      "tile-#{id}"
    end

    def heading
      title.presence || id.to_s.tr("-_", "  ").capitalize
    end
  end
end
