# frozen_string_literal: true

Rails.application.routes.draw do
  # Audited records
  resources :records, param: :composite_id, constraints: { composite_id: /[^\/]+\/[^\/]+/ } do
    member do
      get :history
      get :state_at
      get :proof
      get :diff
    end
    collection do
      get :search
      get :types
    end
  end

  # Audit logs and reports
  resources :audit_logs, only: [:index, :show] do
    collection do
      get :report
      get :export
    end
  end

  # API namespace
  namespace :api do
    namespace :v1 do
      resources :records, param: :composite_id, constraints: { composite_id: /[^\/]+\/[^\/]+/ }
    end
  end

  root 'records#index'
end
