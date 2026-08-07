# Anomonitor

Rails engine gem that watches **Sidekiq**, **Delayed Job**, **Solid Queue**, and **custom job tables** for anomalies — threshold breaches, growth spikes, and **schema drift** — then notifies via **webhook** and shows an ops **dashboard**.

<img width="1512" height="836" alt="anomonitor" src="https://github.com/user-attachments/assets/62938225-02a7-4e5c-8baf-d8ec24658a79" />

## Install

```ruby
# Gemfile
gem "anomonitor", github: "flori-s/anomonitor"
```

Requires **Ruby >= 3.0** and **Rails >= 6.1**.

```bash
bundle install
rails generate anomonitor:install
rails railties:install:migrations FROM=anomonitor
rails db:migrate
```

Mount the engine:

```ruby
# config/routes.rb
mount Anomonitor::Engine => "/anomonitor"
```

## Configure

`config/initializers/anomonitor.rb`:

```ruby
Anomonitor.configure do |c|
  c.webhook_url = ENV.fetch("ANOMONITOR_WEBHOOK_URL")
  c.poll_interval = 60
  c.cooldown = 15 * 60

  c.collectors.sidekiq = true
  c.collectors.delayed_job = true
  c.collectors.solid_queue = true

  c.alert :queue_depth, max: 1_000
  c.alert :growth_spike, window: 5 * 60, multiplier: 3.0
end
```

### Multi-tenancy + schema drift

For Apartment / schema-per-tenant apps, set `tenants` so Delayed Job is collected **per tenant** and enable schema drift:

```ruby
Anomonitor.configure do |c|
  c.tenants = -> { CustomerTenant.pluck(:name) }
  c.exclude_tenants = %w[public]
  # optional — defaults to Apartment::Tenant.switch when Apartment is loaded
  c.tenant_switch = ->(name, &block) { Apartment::Tenant.switch(name, &block) }

  c.collectors.delayed_job = true
  c.collectors.schema_drift = true
  c.schema_drift_exclude = %w[
    schema_migrations
    ar_internal_metadata
    anomonitor_*
    a*
    conv_*
  ]

  c.alert :queue_depth, max: 1_000
  c.alert :missing_tables, max: 0
  c.alert :extra_tables, max: 0
  c.alert :missing_columns, max: 0
  c.alert :extra_columns, max: 0
end
```

`schema_drift_exclude` accepts exact names or `File.fnmatch` globs (`a*` matches all a-prefixed tables; `a_*` only matches `a_…`).

### Custom tables

Status-based queues:

```ruby
c.table :customer_jobs do |t|
  t.model = "Job"
  t.timestamp = :created_at
  t.status = :status
  t.active = %w[pending running]
end
```

Cross-tenant Delayed Job index (host provides an AR model, e.g. `SuppJob` → `public.supp_jobs`):

```ruby
c.table :supp_jobs do |t|
  t.model = "SuppJob"
  t.style = :delayed_job   # failed_at / locked_at / run_at / locked_by
  t.tenant = :tenant       # emit per-tenant metrics
end
```

### Webhooks

Set `ANOMONITOR_WEBHOOK_URL`. Slack Incoming Webhooks (`hooks.slack.com`) get a formatted `text` payload (includes tenant when present). Other URLs receive JSON:

```json
{
  "gem": "anomonitor",
  "event": "anomaly.detected",
  "severity": "high",
  "rule": "growth_spike",
  "source": "delayed_job",
  "metric": "queue_depth",
  "value": 4200,
  "threshold": 1000,
  "sampled_at": "2026-08-07T09:00:00Z",
  "dashboard_url": "/anomonitor/anomalies/123",
  "tags": { "tenant": "acme" }
}
```

## Polling: thread vs cron

Anomonitor can collect on a background thread **or** via an external scheduler.

| `poll_mode` | Behavior |
|---|---|
| `:thread` (default) | Starts an in-process poller after boot (`poll_interval` seconds). Avoid with multi-worker Puma/Unicorn unless only one worker should run it. |
| `:cron` | No background thread. Schedule `rails anomonitor:poll` yourself. |

```ruby
# In-process (default)
c.poll_mode = :thread

# Cron / systemd / Kubernetes CronJob / whenever
c.poll_mode = :cron
```

Cron examples:

```cron
* * * * * cd /app && bin/rails anomonitor:poll
```

```ruby
# config/schedule.rb (whenever)
every 1.minute do
  rake "anomonitor:poll"
end
```

`c.auto_start = false` is still supported and is equivalent to `poll_mode = :cron`.

## Dashboard

Open `/anomonitor` for:

- Current metric cards and mini history bars
- Recent anomalies + delivery status
- Poller health (last run, collector status)

## Manual poll

```bash
rails anomonitor:poll
```

With Apartment, the rake task switches to the first `exclude_tenants` entry (default `public`) before collecting.

## Development

```bash
bundle install
bundle exec rake test
```

## License

MIT
