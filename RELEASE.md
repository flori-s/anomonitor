# Releasing Anomonitor

## Version bump

1. Update `lib/anomonitor/version.rb`
2. Add a section to `CHANGELOG.md`
3. Commit and tag: `git tag v0.6.1 && git push origin v0.6.1`

## RubyGems

Requires owner credentials on rubygems.org for the `anomonitor` gem.

```bash
gem build anomonitor.gemspec
gem push anomonitor-0.6.1.gem
```

Or:

```bash
bundle exec rake release
```

(if a `release` task is configured via bundler gem tasks)

## GitHub-only installs

Until published, hosts can use:

```ruby
gem "anomonitor", github: "flori-s/anomonitor", tag: "v0.6.1"
```
