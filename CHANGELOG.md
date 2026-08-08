# Changelog

## 0.5.0

- Manual resolve/ack and reopen on anomaly detail (sticky silence until clear)
- Retry failed webhooks from UI and `rails anomonitor:retry_webhooks`
- Full schema-drift `items_list` in tags (detail page shows all items)
- Boot config warnings (`ConfigurationValidator`)
- Jobs browser search (`q`) by job class/name
- Metrics export: `/anomonitor/metrics.json` and `/anomonitor/metrics.prom`
- Poll advisory/file lock (`c.poll_lock`, default on) + cooperative thread stop
- Spike baselines sample more candidates before tag filter
- Dedupe Solid Queue / status-table metrics (single `queue_depth`)
- Remove unused `ApplicationJob`

## 0.4.1

- Pluggable `c.notifier` (callable / `#deliver` / array) + `Anomonitor::Notifiers.payload` for host transports like `Webhook::Broadcast`

## 0.4.0

- Absolute webhook dashboard URLs via `dashboard_base_url` / `ANOMONITOR_DASHBOARD_BASE_URL`
- Sticky schema drift: `anomaly.resolved` webhook when drift clears; anomalies UI open/resolved filter
- Fingerprint full item sets (`items_digest`) so changes beyond the first 25 still re-alert
- Jobs browser: Delayed Job / table `pending` matches collectors (`run_at <= now`); hide `locked` for status-style tables
- Dashboard auth hook (`c.authenticate`) + docs / SECURITY note
- Default install alerts for `failed` and `latency`
- `schema_drift_interval` (default 15m) so drift polls less often than queue metrics
- Prune old anomalies with `retention_days` (keep open schema-drift rows)
- GitHub Actions CI (`rake test` on Ruby 3.1–3.3)

## 0.3.2

- Schema drift alerts are sticky: notify once, stay silent until the drift clears or the item set changes (no 15‑minute re-alerts)
- Anomalies gain `resolved_at` for sticky resolution
- Jobs browser: honor `queue` filter for custom tables and Delayed Job

## 0.3.1

- Update slack text ```"<#{dashboard}|Open anomaly>" -> "<#{dashboard}>"```

## 0.3.0

- Jobs dashboard: collector health cards + read-only live job browser for Sidekiq, Delayed Job, Solid Queue, and custom tables

## 0.2.3

- Wrap long metric/anomaly tag lines so tables stay within the viewport

## 0.2.2

- Stop auto-appending engine migrations (use `rails anomonitor:install:migrations`) so Apartment hosts can own public-only copies without duplicate migration names

## 0.2.1

- Support Rails `>= 6.1` (migrations use `ActiveRecord::Migration[6.1]`)
- Dashboard cron mode UI (mode/schedule/last run from samples)

## 0.2.0

- Multi-tenancy: `tenants`, `exclude_tenants`, `tenant_switch` (Apartment-aware by default)
- Per-tenant Delayed Job metrics when tenants are configured
- Schema drift collector (`missing_tables` / `extra_tables` / `missing_columns` / `extra_columns`)
- Configurable `schema_drift_exclude` globs
- Custom tables: `style: :delayed_job` and optional `tenant:` for per-tenant index tables
- Tenant-aware cooldown keys, spike baselines, and Slack webhook text
- `poll_mode` `:thread` (default) or `:cron` — cron uses `rails anomonitor:poll`

## 0.1.0

- Initial release: Sidekiq, Delayed Job, Solid Queue, and custom table collectors
- Threshold and growth-spike detection with cooldown
- Webhook notifier
- Mountable dashboard (overview, anomalies, metrics)
