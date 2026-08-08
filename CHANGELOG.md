# Changelog

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
