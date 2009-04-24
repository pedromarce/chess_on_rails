class ChatsController < ApplicationController

  def show
  end

  # POST /match/N/chat
  def create
    chat = Chat.new(params[:chat])
    chat.text.gsub!( '<', '&lt;' ).gsub!( '>', '&gt;' )
    respond_to do |format|
      if chat.save
        format.html { render :action => :show }
      end
    end
  end

  private
  def chats
    @chats ||= Chat.find_all_by_match_id( params[:match_id] )
  end
  helper_method :chats
end
