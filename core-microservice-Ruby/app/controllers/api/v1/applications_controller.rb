module Api
  module V1
    class ApplicationsController < ApplicationController
      def show
        begin
            # Use find_by! which raises ActiveRecord::RecordNotFound if the application is not found
            app = Application.find_by!(token: params[:id])

            # If the code reaches here, the application was successfully found
            render json: {
                status: "SUCCESS",
                data: {
                    name: app.name,
                    token: app.token,
                    # Including other useful attributes like chats_count for completeness
                    chats_count: app.chats_count 
                }
            }, status: :ok

        # Catch the specific error raised when find_by! fails
        rescue ActiveRecord::RecordNotFound
            render json: {
                status: "Application Not Found",
                error: "No application found with the token: #{params[:id]}"
            }, status: :not_found

        # Catch any other unexpected errors
        rescue StandardError => e
            render json: {
                status: "General Error",
                error: e.message
            }, status: :internal_server_error
        end
      end

      def create
        begin
          app = Application.new(application_params)
          if app.save
            render json: {status: "Application Created Successfully", data: {
              name: app.name,
              token: app.token
            }}, status: :ok
          else
            render json: {status: "Couldn't Add Application", data: app.errors}, status: :unprocessable_entity
          end
        rescue ActiveRecord::RecordNotFound => e
          render json: {status: "General Error", error: e}, status: :internal_server_error
        end
      end

      def update
      begin
          app = Application.find_by!(token: params[:id])

          if app.update(application_params)
              render json: {
                  status: "Application Updated Successfully",
                  data: {
                      name: app.name,
                      token: app.token,
                      chats_count: app.chats_count 
                  }
              }, status: :ok
          else
              render json: {
                  status: "Couldn't Update Application",
                  data: app.errors
              }, status: :unprocessable_entity
          end

      rescue ActiveRecord::RecordNotFound
          render json: {
              status: "Application Not Found",
              error: "No application found with the token: #{params[:token]}"
          }, status: :not_found
          
      rescue StandardError => e
          render json: {
              status: "General Error",
              error: e.message
          }, status: :internal_server_error
      end
    end

    private
      def application_params
          params.require(:application).permit(:name)
      end
    end
  end
end