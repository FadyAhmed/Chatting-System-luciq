# app/controllers/api/v1/messages_controller.rb

module Api
  module V1
    class MessagesController < ApplicationController
      # Ensure Application and Chat are loaded before executing the index action
      before_action :set_application
      before_action :set_chat
      
      # Define pagination constants
      PER_PAGE = 5
      
      # GET /applications/:application_token/chats/:chat_id/messages
      def index
        begin
          # 1. Fetch messages for the specific chat
          # 2. Sort them by creation date in descending order (newest first)
          messages = @chat.messages.order(created_at: :desc)
                                  
          # 3. Apply pagination (using kaminari's page and per methods)
          # Get page number from query params, default to 1
          page_number = params[:page].to_i > 0 ? params[:page].to_i : 1
          paginated_messages = messages.page(page_number).per(PER_PAGE)

          # 4. Render the JSON response
          render json: {
            status: "SUCCESS",
            metadata: {
              current_page: paginated_messages.current_page,
              total_pages: paginated_messages.total_pages,
              total_count: paginated_messages.total_count,
              per_page: PER_PAGE
            },
            data: paginated_messages.map { |message|
              {
                id: message.id,
                chat_id: message.chat_id,
                number: message.number,
                body: message.body, # Assuming a 'body' attribute for the message content
                created_at: message.created_at
              }
            }
          }, status: :ok

        rescue ActiveRecord::RecordNotFound => e
          render json: {
            status: "Error",
            error: e.message # Will catch errors from set_application or set_chat
          }, status: :not_found

        rescue StandardError => e
          render json: {
            status: "General Error",
            error: e.message
          }, status: :internal_server_error
        end
      end

      private
      
      # Helper methods (you may move these to ApplicationController if shared)
      
      # NOTE: This method is assumed to be defined/available in the original controller, 
      # but it needs to be in this MessagesController or a parent class.
      def set_application
        @application = Application.find_by!(token: params[:application_token])
      rescue ActiveRecord::RecordNotFound
        render json: {
          status: "Application Not Found",
          error: "No application found with token: #{params[:application_token]}"
        }, status: :not_found and return # Use 'and return' to stop execution
      end

      # NOTE: Assuming the 'chat_id' parameter is passed as 'chat_id' in the route path,
      # but Rails uses the resource name's ID by default, which is :chat_id in the URL.
      def set_chat
        @chat = @application.chats.find_by!(id: params[:chat_id])
      rescue ActiveRecord::RecordNotFound
        render json: {
          status: "Chat Not Found",
          error: "No chat found with id: #{params[:chat_id]} for application: #{params[:application_token]}"
        }, status: :not_found and return
      end

    end
  end
end