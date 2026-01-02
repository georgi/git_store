# frozen_string_literal: true

Rails.application.routes.draw do
  # Configuration management routes
  resources :configs, param: :path, path: 'configs', constraints: { path: /.*/ } do
    member do
      get :history
      post :rollback
      get :diff
    end
    collection do
      get :environments
      get 'environment/:env', action: :environment, as: :environment
    end
  end

  # API namespace for programmatic access
  namespace :api do
    namespace :v1 do
      resources :configs, param: :path, constraints: { path: /.*/ }, only: [:index, :show, :create, :update, :destroy]
    end
  end

  root 'configs#index'
end
