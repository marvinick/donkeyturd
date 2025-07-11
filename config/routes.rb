Rails.application.routes.draw do
  devise_for :users, controllers: {
    omniauth_callbacks: 'users/omniauth_callbacks'
  }

  resources :listings do
    collection do
      get :search
      get :search_external
      post :import_external
      get :api_status
      get :map
    end
  end
  
  # City SEO routes
  resources :cities, only: [:index, :show] do
    # View type specific pages: /cities/banff-alberta/mountain-views
    member do
      get ':view_type', to: 'cities#view_type', as: 'view_type',
          constraints: { view_type: /mountain|ocean|lake|city|desert|forest|river|canyon|valley|beach/ }
    end
  end
  
  # Admin routes
  namespace :admin do
    resources :sitemap, only: [:index] do
      collection do
        post :generate
        post :submit
        post :ping
      end
    end
    
    resources :blog_posts do
      member do
        patch :publish
        patch :unpublish
        patch :toggle_featured
      end
    end
  end
  
  # Public blog routes
  resources :blog, only: [:index, :show], path: 'blog', controller: 'blog'
  
  # SEO-friendly view routes
  get "/mountain-views", to: 'listings#index', defaults: { view_type: 'mountain' }, as: "mountain_views"
  get "/ocean-views", to: 'listings#index', defaults: { view_type: 'ocean' }, as: "ocean_views"
  get "/lake-views", to: 'listings#index', defaults: { view_type: 'lake' }, as: "lake_views"
  get "/city-views", to: 'listings#index', defaults: { view_type: 'city' }, as: "city_views"
  get "/desert-views", to: 'listings#index', defaults: { view_type: 'desert' }, as: "desert_views"
  get "/forest-views", to: 'listings#index', defaults: { view_type: 'forest' }, as: "forest_views"
  get "/river-views", to: 'listings#index', defaults: { view_type: 'river' }, as: "river_views"
  get "/canyon-views", to: 'listings#index', defaults: { view_type: 'canyon' }, as: "canyon_views"
  get "/valley-views", to: 'listings#index', defaults: { view_type: 'valley' }, as: "valley_views"
  get "/beach-views", to: 'listings#index', defaults: { view_type: 'beach' }, as: "beach_views"
  
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "listings#index"
end
