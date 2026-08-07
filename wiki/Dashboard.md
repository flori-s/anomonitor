# Dashboard

Mounted at `/anomonitor` (or your custom mount path).

## Overview (`/`)

- Poller status (running / last run / interval / errors)
- Latest metric cards
- Mini history bars (last 24h)
- Recent anomalies

## Anomalies (`/anomalies`)

List and detail views with rule, value, threshold, and webhook status.

## Metrics (`/metrics`)

Recent samples from the last 24 hours.

## Manual poll

```bash
rails anomonitor:poll
```

Useful when `auto_start` is false or you want an immediate tick in console/ops.
