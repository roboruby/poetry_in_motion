# A user turn: the message persists at once (its row streams to every open
# tab) and the analyst answers from a background job.
class MessagesController < ApplicationController
  before_action :set_chat

  def create
    content = params.dig(:message, :content).to_s.strip
    if content.present?
      @chat.update!(title: content.truncate(60)) if @chat.title.blank?
      @chat.create_user_message(content)
      ChatResponseJob.perform_later(@chat.id)
    end

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @chat }
    end
  end

  private

  def set_chat
    @chat = Chat.find(params[:chat_id])
  end
end
