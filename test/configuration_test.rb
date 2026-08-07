# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < AnomonitorTestCase
  def test_default_collectors_enabled
    cfg = Anomonitor.config
    assert cfg.collectors.sidekiq
    assert cfg.collectors.delayed_job
    assert cfg.collectors.solid_queue
  end

  def test_configure_webhook_and_alerts
    Anomonitor.configure do |c|
      c.webhook_url = "https://example.com/hook"
      c.poll_interval = 30
      c.alert :queue_depth, max: 500
      c.alert :growth_spike, window: 300, multiplier: 2.5
      c.table :customer_jobs do |t|
        t.model = "Job"
        t.active = %w[pending]
      end
    end

    assert_equal "https://example.com/hook", Anomonitor.config.webhook_url
    assert_equal 30, Anomonitor.config.poll_interval
    assert_equal 2, Anomonitor.config.alerts.size
    assert Anomonitor.config.alerts.first.threshold?
    assert Anomonitor.config.alerts.last.spike?
    assert_equal 1, Anomonitor.config.tables.size
    assert_equal "Job", Anomonitor.config.tables.first.model
  end
end
