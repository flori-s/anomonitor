# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < AnomonitorTestCase
  def test_default_collectors_enabled
    cfg = Anomonitor.config
    assert cfg.collectors.sidekiq
    assert cfg.collectors.delayed_job
    assert cfg.collectors.solid_queue
    refute cfg.collectors.schema_drift
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
      c.table :supp_jobs do |t|
        t.model = "IndexJob"
        t.style = :delayed_job
        t.tenant = :tenant
      end
    end

    assert_equal "https://example.com/hook", Anomonitor.config.webhook_url
    assert_equal 30, Anomonitor.config.poll_interval
    assert_equal 2, Anomonitor.config.alerts.size
    assert Anomonitor.config.alerts.first.threshold?
    assert Anomonitor.config.alerts.last.spike?
    assert_equal 2, Anomonitor.config.tables.size
    assert_equal "Job", Anomonitor.config.tables.first.model
    assert Anomonitor.config.tables.last.delayed_job_style?
    assert_equal :tenant, Anomonitor.config.tables.last.tenant
  end

  def test_poll_mode_cron_disables_auto_start
    Anomonitor.configure { |c| c.poll_mode = :cron }
    assert_equal :cron, Anomonitor.config.poll_mode
    refute Anomonitor.config.auto_start
  end

  def test_auto_start_false_sets_poll_mode_cron
    Anomonitor.configure { |c| c.auto_start = false }
    assert_equal :cron, Anomonitor.config.poll_mode
    refute Anomonitor.config.auto_start
  end

  def test_poll_mode_rejects_invalid
    assert_raises(ArgumentError) do
      Anomonitor.configure { |c| c.poll_mode = :sidekiq }
    end
  end

  def test_anomaly_dashboard_url_absolute_and_relative
    Anomonitor.configure do |c|
      c.dashboard_path = "/anomonitor"
      c.dashboard_base_url = nil
    end
    assert_equal "/anomonitor/anomalies/9", Anomonitor.config.anomaly_dashboard_url(9)

    Anomonitor.configure { |c| c.dashboard_base_url = "https://ops.example.com/" }
    assert_equal "https://ops.example.com/anomonitor/anomalies/9", Anomonitor.config.anomaly_dashboard_url(9)
  end

  def test_schema_drift_interval_default
    assert_equal 15 * 60, Anomonitor.config.schema_drift_interval
  end
end
