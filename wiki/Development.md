# Development

## Layout

```
lib/anomonitor/           # config, poller, detector, collectors, webhook
app/                      # engine models, controllers, views
db/migrate/               # metric samples + anomalies
test/                     # minitest suite
wiki/                     # this documentation
```

## Tests

```bash
bundle install
bundle exec rake test
# or without bundler, if gems are already installed:
ruby -Ilib:test -e 'require "minitest/mock"; Dir["test/**/*_test.rb"].sort.each { |f| require "./#{f}" }'
```

## Version

See `lib/anomonitor/version.rb` and `CHANGELOG.md`.

## Security

See [SECURITY.md](../SECURITY.md) in the repository root.
