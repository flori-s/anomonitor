# Alerts & Webhooks

## Alert rules

### Threshold

Fires when a metric value exceeds `max`:

```ruby
c.alert :queue_depth, max: 1_000, severity: "high"
```

### Growth spike

Fires when the current value is at least `multiplier`× the previous window (or `tags["previous"]` for table growth):

```ruby
c.alert :growth_spike, window: 5 * 60, multiplier: 3.0
```

## Cooldown

After an anomaly is recorded for a cooldown key (`rule:source:metric[:queue]`), the same key will not alert again until `cooldown` seconds pass.

## Webhook payload

`POST` JSON to `webhook_url` (retries once on HTTP 5xx):

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
  "dashboard_url": "/anomonitor/anomalies/123",
  "tags": {}
}
```

Delivery status is stored on the anomaly (`pending` / `delivered` / `failed`).
