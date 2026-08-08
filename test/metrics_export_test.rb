# frozen_string_literal: true

require "test_helper"

class MetricsExportTest < AnomonitorTestCase
  def test_json_and_prometheus_export
    Anomonitor::MetricSample.create!(
      source: "sidekiq",
      metric: "queue_depth",
      value: 42,
      tags: { "queue" => "default" },
      sampled_at: Time.current
    )
    Anomonitor::Anomaly.create!(
      rule: "threshold",
      source: "sidekiq",
      metric: "queue_depth",
      value: 42,
      threshold: 10,
      severity: "high",
      cooldown_key: "export:1",
      sampled_at: Time.current
    )

    json = Anomonitor::MetricsExport.json_payload
    assert_equal 1, json[:open_anomalies]
    assert json[:metrics].any? { |m| m[:metric] == "queue_depth" }

    text = Anomonitor::MetricsExport.prometheus_text
    assert_includes text, "anomonitor_open_anomalies 1"
    assert_includes text, "anomonitor_metric{"
    assert_includes text, "queue_depth"
  end
end
