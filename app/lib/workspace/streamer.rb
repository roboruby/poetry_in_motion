module Workspace
  # Everything the app pushes to a chat's page over Turbo Streams: chat rows,
  # the status line, and workspace tiles. Rows and surfaces replace through
  # poetry-agent's versioned `vreplace` action, so a late streaming frame can
  # never repaint a settled row.
  class Streamer
    SETTLED_VERSION = 1_000_000
    # A row appended on creation starts here; streamed frames and the settled
    # render both outrank it.
    INITIAL_VERSION = 0
    MESSAGES_TARGET = "chat-messages".freeze
    SURFACES_TARGET = "surfaces".freeze
    STATUS_TARGET = "chat-status".freeze

    TurboStream = Poetry::Agent::AGUI::TurboStream

    attr_reader :chat

    def initialize(chat)
      @chat = chat
    end

    def append_row(message)
      broadcast TurboStream.append(MESSAGES_TARGET, render("messages/item", message: message, version: INITIAL_VERSION))
    end

    # @param streamed [String, nil] partial assistant text while the model is still writing
    def replace_row(message, version:, streamed: nil)
      html = render("messages/row", message: message, version: version, streamed: streamed)
      broadcast TurboStream.vreplace(message.dom_id_for_row, html, morph: true)
    end

    def remove_row(message)
      broadcast TurboStream.remove(message.dom_id_for_row)
    end

    def status(text)
      broadcast TurboStream.replace(STATUS_TARGET, render("chats/status", text: text))
    end

    def clear_status
      status(nil)
    end

    def error(text)
      broadcast TurboStream.append(MESSAGES_TARGET, render("messages/error", text: text))
    end

    def append_tile(tile)
      broadcast TurboStream.append(SURFACES_TARGET, render("surfaces/tile", tile: tile, chat: chat))
    end

    def replace_tile(tile)
      broadcast TurboStream.replace(tile.dom_id, render("surfaces/tile", tile: tile, chat: chat))
    end

    def replace_surface(tile)
      target = Poetry::Agent::A2UI::Renderer.element_id(tile.surface)
      broadcast TurboStream.vreplace(target, render("surfaces/surface", surface: tile.surface, chat: chat), morph: true)
    end

    def remove_tile(surface_id)
      broadcast TurboStream.remove("tile-#{surface_id}")
    end

    private

    def broadcast(html)
      Turbo::StreamsChannel.broadcast_stream_to(chat, content: html)
    end

    def render(partial, **locals)
      ApplicationController.render(partial: partial, locals: locals)
    end
  end
end
