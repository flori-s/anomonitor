# Configuration

Edit `config/initializers/anomonitor.rb`:

```ruby
Anomonitor.configure do |c|
  c.webhook_url = ENV.fetch("ANOMONITOR_WEBHOOK_URL")
  c.poll_interval = 60          # seconds between collection ticks
  c.cooldown = 15 * 60          # seconds before the same alert can fire again
  c.retention_days = 7          # metric sample retention
  c.dashboard_path = "/anomonitor"
  c.auto_start = true           # start poller after Rails boot

  c.collectors.sidekiq = true
  c.collectors.delayed_job = true
  c.collectors.solid_queue = true

  c.table :customer_jobs do |t|
    t.model = "Job"
    t.timestamp = :created_at
    t.status = :status
    t.active = %w[pending running]
  end

  c.alert :queue_depth, max: 1_000
  c.alert :growth_spike, window: 5 * 60, multiplier: 3.0
end
```

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `webhook_url` | `nil` | URL for anomaly POSTs |
| `poll_interval` | `60` | Seconds between polls |
| `cooldown` | `900` | Dedup window per cooldown key |
| `retention_days` | `7` | How long to keep metric samples |
| `dashboard_path` | `/anomonitor` | Used in webhook `dashboard_url` |
| `auto_start` | `true` | Start background poller on boot |

Set `c.auto_start = false` if you only want manual ticks via `rails anomonitor:poll`.
