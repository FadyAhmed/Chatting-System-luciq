require 'jwt'
require 'redis'

module Api
  module V1
    class UsersController < ApplicationController

      def authenticate
        user = User.find_by(email: params[:email].downcase)

        if user && user.authenticate(params[:password])
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

      def user_params
        params.require(:user).permit(:name, :email, :password, :password_confirmation)
      end

      def encode_token(payload)
        secret = Rails.application.credentials.jwt_secret 
        JWT.encode(payload, secret)
      end

      private

      def connect_redis
        host = ENV.fetch('REDIS_HOST', 'localhost')
        port = ENV.fetch('REDIS_PORT', 6379).to_i
        Redis.new(host: host, port: port)
      rescue StandardError => e
        Rails.logger.error("Failed to connect to Redis: #{e.message}")
        nil 
      end
    end
  end
end