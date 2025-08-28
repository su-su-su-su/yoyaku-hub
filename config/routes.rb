# frozen_string_literal: true

Rails.application.routes.draw do
  get '/terms', to: 'static_pages#terms'
  get '/privacy', to: 'static_pages#privacy'
  get '/demo', to: 'demo#index', as: :demo
  get 'home/index'
  devise_for :users, skip: %i[registrations sessions], controllers: {
    passwords: 'users/passwords',
    omniauth_callbacks: 'users/omniauth_callbacks'
  }
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get 'up' => 'rails/health#show', as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get 'service-worker' => 'rails/pwa#service_worker', as: :pwa_service_worker
  get 'manifest' => 'rails/pwa#manifest', as: :pwa_manifest

  scope '/stylists', module: :stylists do
    get '/', to: redirect('/stylists/sign_up'), as: :sign_up_redirect
    resources :menus_settings, controller: 'menus', only: %i[index new create edit update]
  end

  namespace :stylists do
    resources :products
    get 'dashboard', to: 'dashboards#show'
    get 'schedules/:date', to: 'schedules#show', as: :schedules
    get 'schedules/weekly/:start_date', to: 'schedules#weekly', as: :weekly_schedules
    patch 'schedules/:date/reservation_limits', to: 'schedules#reservation_limits', as: :reservation_limits
    resource :profile, only: [:edit, :update]
    resources :reservations, only: [:show, :index, :new, :create, :edit, :update] do
      member do
        patch :cancel
        resources :accountings, only: [:new, :create, :show, :edit, :update], shallow: true
        resources :chartes, only: [:new, :create], shallow: true
      end
      collection do
        get :update_time_options
      end
    end

    resources :customer_reservations, only: [:new, :create]

    resources :customers, only: [:index, :show, :new, :create, :edit, :update] do
      resources :chartes, only: [:index, :show, :edit, :update, :destroy]
    end

    resources :shift_settings, only: [:index] do
      collection do
        patch 'defaults', to: 'shift_settings#update_defaults', as: 'update_defaults'
        get ':year/:month', to: 'shift_settings#show', as: 'show'
        post ':year/:month', to: 'shift_settings#create', as: 'create'
        patch ':year/:month', to: 'shift_settings#update', as: 'update'
      end
    end
  end

  get 'customers' => redirect('/customers/sign_up')
  get 'login_with_google/:role', to: 'sessions#set_role', as: :set_role_and_auth

  namespace :customers do
    get 'dashboard', to: 'dashboards#show'
    get "stylists/index"
    resources :reservations, only: [:index, :show, :create, :new] do
      member do
        patch :cancel
      end
    end
    resource :profile, only: [:edit, :update]
    resources :stylists, only: [] do
      resources :menus, only: :index, module: 'stylists' do
        post :select_menus, on: :collection
        collection do
          get :weekly, to: 'weeklies#index'
        end
      end
    end
  end

  devise_scope :user do
    get 'stylists/sign_up', to: 'users/registrations#new', as: :new_stylist_registration
    post 'stylists', to: 'users/registrations#create', as: :stylist_registration

    get 'customers/sign_up', to: 'users/registrations#new', as: :new_customer_registration
    post 'customers', to: 'users/registrations#create', as: :customer_registration

    get 'login', to: 'devise/sessions#new', as: :new_user_session
    post 'login', to: 'users/sessions#create', as: :user_session
    delete 'logout', to: 'users/sessions#destroy', as: :destroy_user_session
  end

  unauthenticated do
    root to: 'home#index', as: :unauthenticated_root
  end

  get '/terms', to: 'static_pages#terms'
  get '/privacy', to: 'static_pages#privacy'

  root to: 'home#index'
  # Defines the root path route ("/")
  # root "posts#index"
  if Rails.env.development?
    mount LetterOpenerWeb::Engine, at: "/letter_opener"
  end
end
