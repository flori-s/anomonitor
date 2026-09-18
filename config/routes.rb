Anomonitor::Engine.routes.draw do
  root to: "dashboard#show"
  resources :anomalies, only: %i[index show] do
    member do
      post :resolve
      post :reopen
      post :retry_webhook
    end
  end
  resources :mutes, only: %i[index create destroy]
  # Literal export paths must be declared before `metrics(.:format)`,
  # otherwise /metrics.json is routed to #index with format=json.
  get "metrics.json", to: "metrics#export_json", as: :metrics_json, defaults: { format: :json }
  get "metrics.prom", to: "metrics#export_prometheus", as: :metrics_prom
  get "metrics", to: "metrics#index", as: :metrics
  get "jobs", to: "jobs#index", as: :jobs
end
