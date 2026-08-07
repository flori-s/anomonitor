# Anomonitor Wiki

Welcome to the **Anomonitor** wiki — a Rails engine gem that watches job queues and custom job tables for anomalies, sends webhook alerts, and ships an ops dashboard.

## Pages

- [Installation](Installation.md)
- [Configuration](Configuration.md)
- [Collectors](Collectors.md)
- [Alerts & Webhooks](Alerts-and-Webhooks.md)
- [Dashboard](Dashboard.md)
- [Development](Development.md)

## Quick start

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

```ruby
# config/routes.rb
mount Anomonitor::Engine => "/anomonitor"
```

Set `ANOMONITOR_WEBHOOK_URL`, then open `/anomonitor`.
