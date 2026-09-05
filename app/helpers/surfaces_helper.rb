module SurfacesHelper
  WIDE_ROOTS = %w[Table Chart Grid Tabs].freeze

  # Tiles whose root is a table, chart, grid, or tabs take the full row.
  def tile_classes(tile)
    classes = [ "flex min-w-0 flex-col animate-in fade-in slide-in-from-bottom-2 duration-500" ]
    root = tile.surface.root
    classes << "xl:col-span-2" if root && WIDE_ROOTS.include?(root["component"])
    classes.join(" ")
  end
end
