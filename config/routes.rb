Rails.application.routes.draw do
  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  resources :documents, only: :show do
    member do
      post "lti", to: "documents#show_lti"
      get "preview/pdf", to: "documents#preview_pdf"
      get "preview/gdoc", to: "documents#preview_gdoc"
    end
  end

  resources :materials, only: :show do
    member do
      get "preview/pdf", to: "materials#preview_pdf"
      get "preview/gdoc", to: "materials#preview_gdoc"
    end
  end

  devise_for :users, controllers: {
    registrations: "registrations"
  }

  # Resque dashboard (behind authentication)
  authenticate :user do
    mount Resque::Server, at: "/queue"
  end

  namespace :admin do
    get "/" => "welcome#index"

    resources :resources, except: :show do
      member do
        post :export_to_lti_cc, path: "export-lti-cc"
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
        delete :delete_selected, to: "documents#destroy_selected"
        post :reimport_selected
        get :import_status, to: "documents#import_status"
      end
    end

    resources :materials, except: %i(edit show update) do
      collection do
        delete :delete_selected, to: "materials#destroy_selected"
        post :reimport_selected
        get :import_status, to: "materials#import_status"
      end
    end

    resource :curriculum, only: %i(edit update) do
      get :children
    end

    resources :access_codes, except: :show

    resource :batch_reimport, only: %i(new create) do
      get :import_status, on: :collection
    end

    resources :units, except: %i(show) do
      collection do
        delete :delete_selected, to: "units#destroy_selected"
        # get :student_bundle_status
        # get :teacher_bundle_status
        get :unit_bundle_gdoc_status
        get :unit_bundle_pdf_status
      end
      member do
        # get :student_bundle
        # get :teacher_bundle
        get :unit_bundle_gdoc
        get :unit_bundle_pdf
      end
    end
  end

  namespace :api do
    resources :resources, only: [:index]
  end

  # OAuth callback for Google
  get "/oauth2callback" => "welcome#oauth2callback"

  # Root path
  root to: "welcome#index"
end
