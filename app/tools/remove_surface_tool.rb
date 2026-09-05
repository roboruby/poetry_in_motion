class RemoveSurfaceTool < ApplicationTool
  description "Take a surface off the workspace."
  param :surface_id, required: true

  def execute(surface_id:)
    ok(Workspace::Composer.new(chat).remove(surface_id).to_h)
  end
end
