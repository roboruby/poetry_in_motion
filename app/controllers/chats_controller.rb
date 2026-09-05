class ChatsController < ApplicationController
  before_action :set_chat, only: %i[show destroy]

  def index
    @chats = Chat.recent.limit(30)
  end

  # A new workspace, optionally opened with a first question.
  def create
    chat = Analyst.start
    prompt = params[:prompt].to_s.strip
    if prompt.present?
      chat.update!(title: prompt.truncate(60))
      chat.create_user_message(prompt)
      ChatResponseJob.perform_later(chat.id)
    end
    redirect_to chat
  end

  def show
    @tiles = @chat.tiles
    @messages = @chat.messages.visible.includes(:tool_calls, :parent_tool_call)
  end

  def destroy
    @chat.destroy!
    redirect_to root_path, notice: "Workspace deleted.", status: :see_other
  end

  private

  def set_chat
    @chat = Chat.find(params[:id])
  end
end
