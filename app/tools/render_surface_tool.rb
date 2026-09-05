# The generative UI tool: the agent describes a surface as a flat component
# list plus a data model; the workspace validates it against the catalog,
# persists it, and streams it onto the page as Poetry components.
class RenderSurfaceTool < ApplicationTool
  description "Put a new surface on the workspace (or replace one with the same surface_id) built from the component " \
              "vocabulary in your instructions. Exactly one component has id \"root\". Returns ok with any rendering " \
              "warnings, or errors to fix and retry."
  params Workspace::Vocabulary::RENDER_SCHEMA

  def execute(surface_id:, title:, components:, data: nil)
    result = Workspace::Composer.new(chat).render(surface_id: surface_id, title: title, components: components, data: data)
    ok(result.to_h)
  end
end
