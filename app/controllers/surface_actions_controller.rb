# The surfaces' way back into the conversation: a Button with an agent event
# posts here. The submitted values are written into the surface's data
# model, the event becomes a user turn the analyst answers, and the surface
# re-renders with its checks' errors when the submission fails them.
class SurfaceActionsController < ApplicationController
  before_action :set_chat

  def create
    payload = params.require(:a2ui).permit(:surface, :action, values: {}).to_h
    session = @chat.surface_session
    surface_id = payload["surface"].to_s
    action = session.action(surface_id: surface_id, source: payload["action"].to_s, values: payload["values"] || {})
    return head :unprocessable_content unless action

    surface = session.surface(surface_id)
    if action.valid?
      persist_values(surface, payload["values"] || {})
      event = action.to_h["action"]
      @chat.create_user_message("#{Message::ACTION_PREFIX} #{event["name"]} on #{surface_id}: #{event["context"].to_json}")
      ChatResponseJob.perform_later(@chat.id)
      render body: surface_stream(surface), content_type: "text/vnd.turbo-stream.html"
    else
      render body: surface_stream(surface, errors: action.errors), content_type: "text/vnd.turbo-stream.html",
             status: :unprocessable_content
    end
  end

  private

  def set_chat
    @chat = Chat.find(params[:chat_id])
  end

  # The session already holds the coerced values; the event log gets the
  # same writes so the next replay agrees with the page.
  def persist_values(surface, values)
    bound = surface.inputs.map { |input| input[:path] }
    values.each_key do |path|
      next unless bound.include?(path.to_s)

      value = Poetry::Agent::A2UI::Pointer.get(surface.data, path.to_s)
      event = UiEvent.from_message({ "updateDataModel" => { "surfaceId" => surface.id, "path" => path.to_s, "value" => value } })
      event.chat = @chat
      event.save!
    end
  end

  def surface_stream(surface, errors: {})
    html = render_to_string(partial: "surfaces/surface", locals: { surface: surface, chat: @chat, errors: errors }, formats: [ :html ])
    Poetry::Agent::AGUI::TurboStream.vreplace(Poetry::Agent::A2UI::Renderer.element_id(surface), html, morph: true)
  end
end
