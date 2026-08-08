require_relative "lib/anomonitor/version"

Gem::Specification.new do |spec|
  spec.name        = "anomonitor"
  spec.version     = Anomonitor::VERSION
  spec.authors     = ["flori-s"]
  spec.email       = ["150121780+flori-s@users.noreply.github.com"]
  spec.homepage    = "https://github.com/flori-s/anomonitor"
  spec.summary     = "Monitor job queues and custom job tables for anomalies"
  spec.description = "Mountable Rails engine that collects Sidekiq, Delayed Job, Solid Queue, " \
                     "and custom table metrics, detects threshold and growth spikes, " \
                     "sends webhook alerts, and provides an ops dashboard."
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md", "CHANGELOG.md", "SECURITY.md", "RELEASE.md"]
  end

  spec.add_dependency "rails", ">= 6.1"
end
