Anomonitor::Engine.routes.draw do
  root to: "dashboard#show"
  resources :anomalies, only: %i[index show] do
    member do
      post :resolve
      post :reopen
      post :retry_webhook
    end
  end
  get "metrics", to: "metrics#index", as: :metrics
  get "metrics.json", to: "metrics#export_json", as: :metrics_json
  get "metrics.prom", to: "metrics#export_prometheus", as: :metrics_prom
  get "jobs", to: "jobs#index", as: :jobs
end
