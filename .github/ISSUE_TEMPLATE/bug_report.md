---
name: Bug report
about: Something broken in collectors, alerts, webhooks, or the dashboard
title: "[Bug] "
labels: ["bug"]
assignees: ""
---

**Describe the bug**
A clear and concise description of what went wrong.

**To reproduce**
Steps to reproduce the behavior:
1.
2.
3.

**Expected behavior**
What you expected to happen.

**Environment**
- Anomonitor version / commit:
- Ruby version:
- Rails version:
- Queue adapter(s): Sidekiq / Delayed Job / Solid Queue / none
- Custom job tables configured? (yes/no):

**Relevant config**
Paste a redacted snippet from `config/initializers/anomonitor.rb` (remove webhook secrets/URLs if needed).

```ruby

```

**Logs / error**
Poller errors, webhook failures, or stack traces:

```text

```

**Dashboard**
If UI-related: page URL, browser, and a screenshot if useful.

**Additional context**
Anything else that might help (hosting, Redis, DB adapter, etc.).
