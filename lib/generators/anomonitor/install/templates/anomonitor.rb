# frozen_string_literal: true

Anomonitor.configure do |c|
  c.webhook_url = ENV["ANOMONITOR_WEBHOOK_URL"]
  c.poll_interval = 60
  c.cooldown = 15 * 60
  c.retention_days = 7
  c.dashboard_path = "/anomonitor"
  c.auto_start = true

  c.collectors.sidekiq = true
  c.collectors.delayed_job = true
  c.collectors.solid_queue = true

  # Example custom job table — uncomment and adjust:
  # c.table :customer_jobs do |t|
  #   t.model = "Job"
  #   t.timestamp = :created_at
  #   t.status = :status
  #   t.active = %w[pending running]
  # end

  c.alert :queue_depth, max: 1_000
  c.alert :growth_spike, window: 5 * 60, multiplier: 3.0
end
