Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
  root "home#show"

  get "testimonies", to: "public_entities#index", defaults: { label: "Testimony" }, as: :testimonies
  get "testimonies/:external_id", to: "public_entities#show", defaults: { label: "Testimony", format: false }, as: :testimony

  get "people", to: "public_entities#index", defaults: { label: "Person" }, as: :people
  get "people/:external_id", to: "public_entities#show", defaults: { label: "Person", format: false }, as: :person

  get "organisations", to: "public_entities#index", defaults: { label: "Organisation" }, as: :organisations
  get "organisations/:external_id", to: "public_entities#show", defaults: { label: "Organisation", format: false }, as: :organisation

  get "events", to: "public_entities#index", defaults: { label: "Event" }, as: :events
  get "events/:external_id", to: "public_entities#show", defaults: { label: "Event", format: false }, as: :event

  get "allegations", to: "public_entities#index", defaults: { label: "Allegation" }, as: :allegations
  get "allegations/:external_id", to: "public_entities#show", defaults: { label: "Allegation", format: false }, as: :allegation

  get "evidence", to: "public_entities#index", defaults: { label: "Evidence" }, as: :evidence_index
  get "evidence/:external_id", to: "public_entities#show", defaults: { label: "Evidence", format: false }, as: :evidence
end
