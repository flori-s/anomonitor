source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

gemspec

# Allow CI to pin Rails; default keeps a stable local/dev baseline.
gem "rails", ENV.fetch("RAILS_VERSION", "~> 7.1")

# Rails 8 needs sqlite3 >= 2.1 (Ruby >= 3.1). Older Rubies stay on 1.7.x.
if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new("3.1")
  gem "sqlite3", ">= 2.1"
else
  gem "sqlite3", "~> 1.7"
end

group :development, :test do
  gem "minitest", "~> 5.0"
end
