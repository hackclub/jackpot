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
   post "/deck/unship_project", to: "deck#unship_project", as: :unship_project
   delete "/deck/delete_project", to: "deck#delete_project", as: :delete_project
   post "/deck/complete_tutorial", to: "deck#complete_tutorial", as: :complete_tutorial
   post "/deck/journal_entries", to: "deck#create_journal_entry", as: :create_journal_entry
     post "/deck/upload_image", to: "deck#upload_image", as: :upload_journal_image
     get "/deck/journal_entries/:project_id", to: "deck#get_journal_entries", as: :get_journal_entries
     post "/deck/approve_project_admin", to: "deck#approve_project_admin", as: :approve_project_admin
     post "/deck/reject_project_admin", to: "deck#reject_project_admin", as: :reject_project_admin
     post "/deck/comment_review_project_admin", to: "deck#comment_review_project_admin", as: :comment_review_project_admin
  get "/leaderboard", to: "leaderboard#index", as: :leaderboard

  get "/shop", to: "shop#index", as: :shop
  post "/shop/buy/:id", to: "shop#buy", as: :buy_shop_item

  get "/req_item", to: "req_item#index", as: :req_item
  post "/req_item", to: "req_item#create"

  get "/admin/shop", to: "admin_shop#index", as: :admin_shop
  get "/admin/shop/orders", to: "admin_shop#orders", as: :admin_shop_orders
  post "/admin/shop/orders/bulk_status", to: "admin_shop#bulk_update_order_status", as: :admin_shop_bulk_order_status
  post "/admin/shop/items", to: "admin_shop#create_item", as: :admin_shop_create_item
  post "/admin/shop/categories", to: "admin_shop#create_category", as: :admin_shop_create_category
  post "/admin/shop/grant_types", to: "admin_shop#create_grant_type", as: :admin_shop_create_grant_type
  patch "/admin/shop/categories/:id", to: "admin_shop#update_category", as: :admin_shop_update_category
  patch "/admin/shop/grant_types/:id", to: "admin_shop#update_grant_type", as: :admin_shop_update_grant_type
  patch "/admin/shop/items/:id", to: "admin_shop#update_item", as: :admin_shop_update_item
  post "/admin/shop/items/reorder", to: "admin_shop#reorder_items", as: :admin_shop_reorder_items
  patch "/admin/shop/purchases_lock", to: "admin_shop#update_purchases_lock", as: :admin_shop_purchases_lock
  delete "/admin/shop/items/:id", to: "admin_shop#delete_item", as: :admin_shop_delete_item
  patch "/admin/shop/orders/:id", to: "admin_shop#update_order_status", as: :admin_shop_update_order

  get "/admin", to: "admin#index", as: :admin
  get "/admin/stats", to: "admin#stats", as: :admin_stats
  get "/admin/items_request", to: "admin#items_request", as: :admin_items_request
  patch "/admin/items_request/:id", to: "admin#update_item_request", as: :admin_update_item_request
  get "/admin/review", to: "admin#review", as: :admin_review
  get "/admin/review/project/:project_id", to: "admin#review_project", as: :admin_review_project
  get "/admin/console", to: "admin#console", as: :admin_console
  post "/admin/console", to: "admin#execute_console", as: :admin_console_execute
  get "/admin/airtable_sync", to: "admin#airtable_sync", as: :admin_airtable_sync
  post "/admin/airtable_sync/force", to: "admin#force_airtable_sync", as: :admin_force_airtable_sync

  namespace :admin do
    constraints AdminConstraint do
      mount Blazer::Engine => "/blazer"
      mount Flipper::UI.app(Flipper) => "/flipper"
      mount MissionControl::Jobs::Engine => "/jobs"
    end
  end

  get "/status", to: "status#index", as: :status
  post "/projects/:project_id/comments", to: "project_comments#create", as: :project_comments

  get "/faq", to: "home#faq", as: :faq
  get "/rules", to: "home#rules", as: :rules

  root "home#index"
  # Defines the root path route ("/")
  # root "posts#index"
end
