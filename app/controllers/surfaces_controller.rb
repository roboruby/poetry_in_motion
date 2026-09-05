# Closing a tile removes the surface without a model turn.
class SurfacesController < ApplicationController
  def destroy
    chat = Chat.find(params[:chat_id])
    Workspace::Composer.new(chat).remove(params[:surface_id])
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove("tile-#{params[:surface_id]}") }
      format.html { redirect_to chat }
    end
  end
end
