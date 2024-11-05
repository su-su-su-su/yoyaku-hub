# frozen_string_literal: true

Rails.application.routes.draw do
  get "customers/dashboard"
  get 'home/index'
  devise_for :users
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get 'up' => 'rails/health#show', as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get 'service-worker' => 'rails/pwa#service_worker', as: :pwa_service_worker
  get 'manifest' => 'rails/pwa#manifest', as: :pwa_manifest

  devise_scope :user do
    get 'customers/sign_in', to: 'devise/sessions#new', defaults: { role: 'customer' }
    get 'stylists/sign_in', to: 'devise/sessions#new', defaults: { role: 'stylist' }
  end

  unauthenticated do
    root to: 'home#index', as: :unauthenticated_root
  end

  root to: 'home#index'
  # Defines the root path route ("/")
  # root "posts#index"
end
