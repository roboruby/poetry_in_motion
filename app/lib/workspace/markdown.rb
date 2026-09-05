module Workspace
  # Assistant text is Markdown; it renders through CommonMark with raw HTML
  # disabled, so model output can never inject markup.
  module Markdown
    OPTIONS = {
      render: { unsafe: false, hardbreaks: true },
      extension: { table: true, strikethrough: true, autolink: true }
    }.freeze

    def self.render(text)
      return "".html_safe if text.blank?

      Commonmarker.to_html(text.to_s, options: OPTIONS).html_safe
    end
  end
end
