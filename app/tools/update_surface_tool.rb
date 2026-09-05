# Evolves a surface in place: components upsert by id, data keys replace at
# the top level, everything else stays. The page morphs the surface.
class UpdateSurfaceTool < ApplicationTool
  description "Change an existing surface without rebuilding it: add or replace components by id, set top-level data " \
              "keys (table rows, chart data, field values), or retitle it. Prefer this over render_surface when the " \
              "user refines a question about the same subject."
  params Workspace::Vocabulary::UPDATE_SCHEMA

  def execute(surface_id:, components: nil, data: nil, title: nil)
    result = Workspace::Composer.new(chat).update(surface_id: surface_id, components: components, data: data, title: title)
    ok(result.to_h)
  end
end
