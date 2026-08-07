# Collectors

Anomonitor collects metrics itself on each poll tick. Disabled or unavailable collectors are skipped (logged at debug/warn).

## Sidekiq

When Sidekiq is loaded:

- `queue_depth` (global + per-queue)
- `busy_workers`, `retries`, `dead`, `failed`, `processed`
- `latency` per queue (when available)

## Delayed Job

When `Delayed::Job` is available:

- `queue_depth` (pending runnable jobs)
- `failed`, `locked`, `total`

## Solid Queue

When Solid Queue tables exist:

- `ready`, `claimed`, `failed`, `scheduled`
- `queue_depth` (ready executions)

## Custom job tables

```ruby
c.table :customer_jobs do |t|
  t.model = "Job"           # ActiveRecord model name
  t.timestamp = :created_at # used for growth windows
  t.status = :status
  t.active = %w[pending running]
end
```

Emits:

- `active` / `queue_depth` — rows in active statuses
- `growth_rate` — rows created in the spike window (with `previous` tag for comparison)

You can register multiple `c.table` sources.
