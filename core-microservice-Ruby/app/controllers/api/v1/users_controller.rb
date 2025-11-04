require 'jwt'
require 'redis'

module Api
  module V1
    class UsersController < ApplicationController

      def authenticate
        # 1. Find the user by email
        user = User.find_by(email: params[:email].downcase)

        # 2. Check password using Rails' has_secure_password
        if user && user.authenticate(params[:password])
          # 3. If authenticated, generate a JWT
          token = encode_token(user_id: user.id, email: user.email)
          
          render json: { 
            status: 'Authentication Successful',
            user_id: user.id,
            name: user.name,
            jwt: token 
          }, status: :ok
        else
          render json: { 
            status: 'Authentication Failed',
            error: 'Invalid email or password' 
          }, status: :unauthorized
        end
      end

      def create
        user = User.new(user_params)
        if user.save
          redis = connect_redis
          redis.sadd('registered:users', user.id)
          # Optionally log the user in immediately after creation
          token = encode_token(user_id: user.id, email: user.email)
          
          render json: { 
            status: 'User Created Successfully',
            user_id: user.id,
            name: user.name,
            jwt: token
          }, status: :created
        else
          render json: { 
            status: 'User Registration Failed',
            errors: user.errors.full_messages 
          }, status: :unprocessable_entity
        end
      end

      private

      # Strong Parameters for mass assignment protection
      def user_params
        # Allows name, email, password, and password_confirmation
        params.require(:user).permit(:name, :email, :password, :password_confirmation)
      end

      # JWT Encoding helper method
      # You will need to install the 'jwt' gem for this to work
      # e.g., gem 'jwt' in your Gemfile
      def encode_token(payload)
        # Define your SECRET_KEY in an environment variable (e.g., Rails credentials)
        secret = Rails.application.credentials.jwt_secret 
        JWT.encode(payload, secret)
      end

      private

      def connect_redis
        Redis.new(host: '127.0.0.1', port: 6379)
      rescue StandardError => e
        Rails.logger.error("Failed to connect to Redis: #{e.message}")
        nil 
      end
    end
  end
end