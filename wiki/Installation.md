# Installation

## Gemfile

```ruby
gem "anomonitor", github: "flori-s/anomonitor"
# or once published:
# gem "anomonitor"
```

## Setup

```bash
bundle install
rails generate anomonitor:install
rails railties:install:migrations FROM=anomonitor
rails db:migrate
```

The install generator creates `config/initializers/anomonitor.rb`.

## Mount the engine

```ruby
# config/routes.rb
mount Anomonitor::Engine => "/anomonitor"
```

Optional path (keep in sync with `c.dashboard_path` in the initializer):

```ruby
mount Anomonitor::Engine => "/ops/anomonitor"
```

## Requirements

- Ruby >= 3.0
- Rails >= 7.0
- Optional adapters: Sidekiq, Delayed Job, and/or Solid Queue (collectors no-op if missing)
