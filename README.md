# Anomonitor

Rails engine gem that watches **Sidekiq**, **Delayed Job**, **Solid Queue**, and **custom job tables** for anomalies — threshold breaches and growth spikes — then notifies via **webhook** and shows an ops **dashboard**.

## Install

```ruby
# Gemfile
gem "anomonitor", github: "flori-s/anomonitor"
```

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

Set `ANOMONITOR_WEBHOOK_URL` to your endpoint. On each anomaly Anomonitor POSTs JSON:

```json
{
  "gem": "anomonitor",
  "event": "anomaly.detected",
  "severity": "high",
  "rule": "growth_spike",
  "source": "sidekiq",
  "metric": "queue_depth",
  "value": 4200,
  "threshold": 1000,
  "sampled_at": "2026-08-07T09:00:00Z",
  "dashboard_url": "/anomonitor/anomalies/123"
}
```

## Dashboard

Open `/anomonitor` for:

- Current metric cards and mini history bars
- Recent anomalies + delivery status
- Poller health (last run, collector status)

## Manual poll

```bash
rails anomonitor:poll
```

## Development

```bash
bundle install
bundle exec rake test
```

## License

MIT
