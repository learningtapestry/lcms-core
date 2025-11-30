Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Documents routes
  resources :documents, only: :show do
    member do
      post 'export', to: 'documents#export'
      get 'export/status', to: 'documents#export_status'
      post 'lti', to: 'documents#show_lti'
    end
  end

  # Materials routes
  resources :materials, only: :show do
    member do
      get 'preview/pdf', to: 'materials#preview_pdf'
      get 'preview/gdoc', to: 'materials#preview_gdoc'
    end
  end

  # Resources routes
  resources :resources, only: [:show]

  # Devise routes
  devise_for :users, controllers: {
    registrations: 'registrations'
  }

  # Resque dashboard (behind authentication)
  authenticate :user do
    mount Resque::Server, at: '/queue'
  end

  # Admin panel
  namespace :admin do
    get '/' => 'welcome#index'

    resources :resources, except: :show do
      member do
        post :export_to_lti_cc, path: 'export-lti-cc'
        post :bundle
      end
    end

    resources :settings, only: [] do
      patch :toggle_editing_enabled, on: :collection
    end

    resources :users, except: :show do
      post :reset_password, on: :member
    end

    resources :standards, only: %i(index edit update) do
      post :import, on: :collection
    end

    resources :documents, except: %i(edit show update) do
      collection do
        delete :delete_selected, to: 'documents#destroy_selected'
        post :reimport_selected
        get :import_status, to: 'documents#import_status'
      end
    end

    resources :materials, except: %i(edit show update) do
      collection do
        delete :delete_selected, to: 'materials#destroy_selected'
        post :reimport_selected
        get :import_status, to: 'materials#import_status'
      end
    end

    resource :curriculum, only: %i(edit update) do
      get :children
    end

    resources :access_codes, except: :show

    resource :batch_reimport, only: %i(new create) do
      get :import_status, on: :collection
    end
  end

  # OAuth callback for Google
  get '/oauth2callback' => 'welcome#oauth2callback'

  # Catch-all route for resources with slugs (must be last)
  get '/*slug' => 'resources#show', as: :show_with_slug

  # Root path
  root to: 'welcome#index'
end
