# frozen_string_literal: true

Rails.application.routes.draw do
  get 'home/index'
  devise_for :users, skip: %i[registrations sessions passwords], controllers: {
    omniauth_callbacks: 'users/omniauth_callbacks'
  }
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get 'up' => 'rails/health#show', as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get 'service-worker' => 'rails/pwa#service_worker', as: :pwa_service_worker
  get 'manifest' => 'rails/pwa#manifest', as: :pwa_manifest

  namespace :stylists do
    get '/', to: redirect('/stylists/sign_up'), as: :sign_up_redirect
    resources :menus_settings, only: [:index, :create, :update], param: :menu_id
  end

  get 'customers' => redirect('/customers/sign_up')
  get 'login_with_google/:role', to: 'sessions#set_role', as: :set_role_and_auth

  get 'customers/dashboard', to: 'customers#show', as: :customers_dashboard
  get 'stylists/dashboard', to: 'stylists#show', as: :stylists_dashboard

  devise_scope :user do
    get 'stylists/sign_up', to: 'users/registrations#new', as: :new_stylist_registration
    post 'stylists', to: 'users/registrations#create', as: :stylist_registration

    get 'customers/sign_up', to: 'users/registrations#new', as: :new_customer_registration
    post 'customers', to: 'users/registrations#create', as: :customer_registration

    get 'login', to: 'devise/sessions#new', as: :new_user_session
    post 'login', to: 'devise/sessions#create', as: :user_session
    delete 'logout', to: 'devise/sessions#destroy', as: :destroy_user_session

    get 'password/new', to: 'devise/passwords#new', as: :new_user_password
    post 'password', to: 'devise/passwords#create', as: :user_password
    get 'password/edit', to: 'devise/passwords#edit', as: :edit_user_password
    patch 'password', to: 'devise/passwords#update'
  end
  unauthenticated do
    root to: 'home#index', as: :unauthenticated_root
  end

  root to: 'home#index'
  # Defines the root path route ("/")
  # root "posts#index"
end
