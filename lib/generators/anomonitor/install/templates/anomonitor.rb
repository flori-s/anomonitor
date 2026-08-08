# frozen_string_literal: true

Anomonitor.configure do |c|
  c.webhook_url = ENV["ANOMONITOR_WEBHOOK_URL"]
  # Absolute origin for Slack/JSON dashboard links (path-only if blank)
  c.dashboard_base_url = ENV["ANOMONITOR_DASHBOARD_BASE_URL"] # e.g. "https://ops.example.com"
  c.poll_interval = 60
  c.cooldown = 15 * 60
  c.retention_days = 7
  c.dashboard_path = "/anomonitor"
  # Schema drift is heavier — poll less often than queue metrics (seconds)
  c.schema_drift_interval = 15 * 60

  # Polling:
  #   :thread — in-process background poller (default; uses poll_interval)
  #   :cron   — no background thread; schedule `rails anomonitor:poll`
  #
  # Cron examples when poll_mode = :cron:
  #   * * * * * cd /app && bin/rails anomonitor:poll
  #   # whenever: every 1.minute do rake "anomonitor:poll" end
  c.poll_mode = :thread
  # c.poll_mode = :cron

  # Protect the dashboard (runs in Anomonitor controllers via instance_exec):
  # c.authenticate = -> {
  #   authenticate_or_request_with_http_basic("Anomonitor") do |user, pass|
  #     ActiveSupport::SecurityUtils.secure_compare(user, ENV.fetch("ANOMONITOR_USER")) &&
  #       ActiveSupport::SecurityUtils.secure_compare(pass, ENV.fetch("ANOMONITOR_PASSWORD"))
  #   end
  # }
  # Or reuse host auth, e.g.:
  # c.authenticate = -> { redirect_to main_app.root_path unless current_user&.admin? }

  c.collectors.sidekiq = true
  c.collectors.delayed_job = true
  c.collectors.solid_queue = true
  c.collectors.schema_drift = false

  # Multi-tenancy (Apartment / schema-per-tenant) — uncomment to enable:
  # c.tenants = -> { CustomerTenant.pluck(:name) }
  # c.exclude_tenants = %w[public]
  # c.tenant_switch = ->(name, &block) { Apartment::Tenant.switch(name, &block) }
  # c.collectors.schema_drift = true
  # c.schema_drift_exclude = %w[schema_migrations ar_internal_metadata anomonitor_* a* conv_*]
  # c.alert :missing_tables, max: 0
  # c.alert :extra_tables, max: 0
  # c.alert :missing_columns, max: 0
  # c.alert :extra_columns, max: 0

  # Custom job table (status-based):
  # c.table :customer_jobs do |t|
  #   t.model = "Job"
  #   t.timestamp = :created_at
  #   t.status = :status
  #   t.active = %w[pending running]
  # end

  # Cross-tenant Delayed Job index (e.g. public.supp_jobs via a host AR model):
  # c.table :supp_jobs do |t|
  #   t.model = "SuppJob"
  #   t.style = :delayed_job
  #   t.tenant = :tenant
  # end

  c.alert :queue_depth, max: 1_000
  c.alert :failed, max: 50
  c.alert :latency, max: 120
  c.alert :growth_spike, window: 5 * 60, multiplier: 3.0
end
