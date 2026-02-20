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
   post "/deck/save_project", to: "deck#save_project", as: :save_project
   post "/deck/ship_project", to: "deck#ship_project", as: :ship_project
   delete "/deck/delete_project", to: "deck#delete_project", as: :delete_project
   post "/deck/complete_tutorial", to: "deck#complete_tutorial", as: :complete_tutorial
   post "/deck/journal_entries", to: "deck#create_journal_entry", as: :create_journal_entry
     get "/deck/journal_entries/:project_index", to: "deck#get_journal_entries", as: :get_journal_entries
     post "/deck/approve_project_admin", to: "deck#approve_project_admin", as: :approve_project_admin
     post "/deck/reject_project_admin", to: "deck#reject_project_admin", as: :reject_project_admin
  get "/leaderboard", to: "leaderboard#index", as: :leaderboard

  get "/shop", to: "shop#index", as: :shop
  post "/shop/buy/:id", to: "shop#buy", as: :buy_shop_item

  get "/admin/shop", to: "admin_shop#index", as: :admin_shop
  post "/admin/shop/items", to: "admin_shop#create_item", as: :admin_shop_create_item
  patch "/admin/shop/items/:id", to: "admin_shop#update_item", as: :admin_shop_update_item
  delete "/admin/shop/items/:id", to: "admin_shop#delete_item", as: :admin_shop_delete_item
  patch "/admin/shop/orders/:id", to: "admin_shop#update_order_status", as: :admin_shop_update_order

  get "/admin", to: "admin#index", as: :admin
  get "/admin/review", to: "admin#review", as: :admin_review

  namespace :admin do
    constraints AdminConstraint do
      mount Blazer::Engine => "/blazer"
      mount Flipper::UI.app(Flipper) => "/flipper"
      mount MissionControl::Jobs::Engine => "/jobs"
    end
  end

  get "/faq", to: "home#faq", as: :faq
  get "/rules", to: "home#rules", as: :rules

  root "home#index"
  # Defines the root path route ("/")
  # root "posts#index"
end
