require_relative "../lib/admin_constraint"

Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  post "/rsvps", to: "rsvps#create"

  # OmniAuth routes
  # Note: OmniAuth middleware handles /auth/:provider internally
  match "/auth/:provider/callback", to: "sessions#create", via: [ :get, :post ]

  get "/auth/hackclub", to: redirect("/")
  get "/auth/failure", to: "sessions#failure"
  delete "/signout", to: "sessions#destroy", as: :signout

  get "/deck", to: "deck#index", as: :deck
  post "/deck/add_project", to: "deck#add_project", as: :add_project
  post "/deck/complete_tutorial", to: "deck#complete_tutorial", as: :complete_tutorial
  get "/leaderboard", to: "leaderboard#index", as: :leaderboard
  get "/admin", to: "admin#index", as: :admin

  namespace :admin do
    constraints AdminConstraint do
      resources :airtable, only: [:index]
      mount Blazer::Engine => "/blazer"
      mount Flipper::UI.app(Flipper) => "/flipper"
      mount MissionControl::Jobs::Engine => "/jobs"
    end
  end

  root "home#index"
  # Defines the root path route ("/")
  # root "posts#index"
end
