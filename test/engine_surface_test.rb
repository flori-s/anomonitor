# frozen_string_literal: true

require "test_helper"

# Lightweight engine surface checks (no full dummy Rails app).
class EngineSurfaceTest < AnomonitorTestCase
  ROOT = File.expand_path("..", __dir__)

  def test_routes_file_declares_expected_resources
    content = File.read(File.join(ROOT, "config/routes.rb"))
    assert_includes content, "resources :anomalies"
    assert_includes content, "resources :mutes"
    assert_includes content, "metrics.json"
    assert_includes content, 'get "jobs"'
  end

  def test_mute_model_matching
    mute = Anomonitor::Mute.create!(
      metric: "extra_tables",
      tenant: "acme",
      muted_until: 1.hour.from_now
    )
    assert mute.matches?(metric: "extra_tables", rule: "threshold", source: "schema_drift", tenant: "acme")
    refute mute.matches?(metric: "extra_tables", rule: "threshold", source: "schema_drift", tenant: "beta")
  end

  def test_version_and_release_docs
    assert Anomonitor::VERSION.start_with?("0.6")
    assert File.exist?(File.join(ROOT, "RELEASE.md"))
  end
end
