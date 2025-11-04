Rails.application.routes.draw do
  namespace "api" do
    namespace "v1" do
      resources :applications, param: :token do
        resources :chats, param: :id do
        end
      end

      resources :users, only: [ :create, :update, :destroy ]
      post "/login", to: "users#authenticate"
    end
  end
end
