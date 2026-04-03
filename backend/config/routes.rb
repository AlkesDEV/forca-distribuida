Rails.application.routes.draw do
  mount ActionCable.server => "/cable"

  namespace :api do
    namespace :v1 do
      get  "status", to: "health#status"
      get  "games/:id", to: "games#show"
    end
  end
end
