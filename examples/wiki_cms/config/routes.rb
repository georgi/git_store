# frozen_string_literal: true

Rails.application.routes.draw do
  # Wiki pages routes
  resources :pages, param: :slug do
    member do
      get :history
      get :diff
      post :rollback
      get :raw
    end
    collection do
      get :recent
      get :search
    end
  end

  # Set wiki home as root
  root 'pages#show', slug: 'home'
end
