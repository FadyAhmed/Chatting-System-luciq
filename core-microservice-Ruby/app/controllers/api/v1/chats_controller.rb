module Api
  module V1
    class ChatsController < ApplicationController
      before_action :set_application
      before_action :set_chat, only: [:show, :update]

      # GET /applications/:application_token/chats
      def index
        begin
          chats = @application.chats
          
          render json: {
            status: "SUCCESS",
            data: chats.map { |chat| 
              {
                id: chat.id,
                number: chat.number,
                user_id: chat.user_id,
                messages_count: chat.messages_count,
                created_at: chat.created_at,
                updated_at: chat.updated_at
              }
            }
          }, status: :ok

        rescue StandardError => e
          render json: {
            status: "General Error",
            error: e.message
          }, status: :internal_server_error
        end
      end

      # GET /applications/:application_token/chats/:id
      def show
        begin
          render json: {
            status: "SUCCESS",
            data: {
              id: @chat.id,
              number: @chat.number,
              user_id: @chat.user_id,
              messages_count: @chat.messages_count,
              created_at: @chat.created_at,
              updated_at: @chat.updated_at
            }
          }, status: :ok

        rescue ActiveRecord::RecordNotFound
          render json: {
            status: "Chat Not Found",
            error: "No chat found with id: #{params[:id]} for application: #{params[:application_token]}"
          }, status: :not_found

        rescue StandardError => e
          render json: {
            status: "General Error",
            error: e.message
          }, status: :internal_server_error
        end
      end

      # POST /applications/:application_token/chats
      def create
        begin
          # Extract user_id from message body
          user_id = chat_params[:user_id]
          
          # Validate that user_id is provided
          if user_id.blank?
            render json: {
              status: "Bad Request",
              error: "user_id is required in the request body"
            }, status: :bad_request
            return
          end

          # Verify the user exists
          user = User.find_by(id: user_id)
          if user.nil?
            render json: {
              status: "User Not Found",
              error: "No user found with id: #{user_id}"
            }, status: :not_found
            return
          end

          # Generate UUID for the chat
          chat_id = SecureRandom.uuid
          Rails.logger.info "Generated UUID: #{chat_id}"

          # Generate the next chat number for this application
          next_chat_number = @application.chats.maximum(:number).to_i + 1
          
          chat = @application.chats.new(
            user_id: user_id, # Set from message body
            number: next_chat_number,
            messages_count: 0
          )

          if chat.save
            # Update application's chats_count
            @application.increment!(:chats_count)
            
            render json: {
              status: "Chat Created Successfully", 
              data: {
                id: chat.id,
                number: chat.number,
                user_id: chat.user_id,
                messages_count: chat.messages_count,
                created_at: chat.created_at
              }
            }, status: :created
          else
            render json: {
              status: "Couldn't Create Chat", 
              data: chat.errors
            }, status: :unprocessable_entity
          end

        rescue StandardError => e
          render json: {
            status: "General Error", 
            error: e.message
          }, status: :internal_server_error
        end
      end

      # PATCH/PUT /applications/:application_token/chats/:id
      def update
        begin
          # Extract user_id from message body for ownership verification
          user_id = chat_params[:user_id]
          
          # Check if the user_id in the request body owns this chat
          if @chat.user_id != user_id
            render json: {
              status: "Forbidden",
              error: "You can only update your own chats"
            }, status: :forbidden
            return
          end

          if @chat.update(chat_params)
            render json: {
              status: "Chat Updated Successfully",
              data: {
                id: @chat.id,
                number: @chat.number,
                user_id: @chat.user_id,
                messages_count: @chat.messages_count,
                updated_at: @chat.updated_at
              }
            }, status: :ok
          else
            render json: {
              status: "Couldn't Update Chat",
              data: @chat.errors
            }, status: :unprocessable_entity
          end

        rescue ActiveRecord::RecordNotFound
          render json: {
            status: "Chat Not Found",
            error: "No chat found with id: #{params[:id]} for application: #{params[:application_token]}"
          }, status: :not_found
          
        rescue StandardError => e
          render json: {
            status: "General Error",
            error: e.message
          }, status: :internal_server_error
        end
      end

      private

      def set_application
        @application = Application.find_by!(token: params[:application_token])
      rescue ActiveRecord::RecordNotFound
        render json: {
          status: "Application Not Found",
          error: "No application found with token: #{params[:application_token]}"
        }, status: :not_found
      end

      def set_chat
        @chat = @application.chats.find_by!(id: params[:id])
      end

      def chat_params
        params.require(:chat).permit(:user_id, :messages_count)
      end
    end
  end
end