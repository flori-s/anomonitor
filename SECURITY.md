# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 0.5.x   | :white_check_mark: |
| 0.4.x   | :white_check_mark: |
| 0.3.x   | :white_check_mark: |
| < 0.3   | :x:                |

## Dashboard access

The Anomonitor engine is **not authenticated by default**. If you mount it on a publicly reachable host, set `c.authenticate` in the initializer (HTTP basic or your app’s admin check). See the README.

## Reporting a Vulnerability

Please report security vulnerabilities privately. Do **not** open a public issue.

- Prefer GitHub Security Advisories for [flori-s/anomonitor](https://github.com/flori-s/anomonitor/security/advisories/new) if available
- Or email the maintainer via the contact listed in the gemspec / GitHub profile

You can expect an initial response within **7 days**. If the report is accepted, we will work on a fix and coordinate disclosure. If declined, we will explain why.
