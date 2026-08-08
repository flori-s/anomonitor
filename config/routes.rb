Anomonitor::Engine.routes.draw do
  root to: "dashboard#show"
  resources :anomalies, only: %i[index show]
  get "metrics", to: "metrics#index", as: :metrics
  get "jobs", to: "jobs#index", as: :jobs
end
