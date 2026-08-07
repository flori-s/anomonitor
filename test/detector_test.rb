# frozen_string_literal: true

require "test_helper"

class DetectorTest < AnomonitorTestCase
  def setup
    super
    Anomonitor.configure do |c|
      c.webhook_url = nil
      c.cooldown = 60
      c.alert :queue_depth, max: 100
      c.alert :growth_spike, window: 300, multiplier: 3.0
    end
  end

  def test_threshold_creates_anomaly
    point = Anomonitor::MetricPoint.new(source: "sidekiq", metric: "queue_depth", value: 250)
    anomalies = Anomonitor::Detector.new.evaluate([point])

    assert_equal 1, anomalies.size
    anomaly = anomalies.first
    assert_equal "threshold", anomaly.rule
    assert_equal 250, anomaly.value
    assert_equal 100, anomaly.threshold
  end

  def test_threshold_ignored_when_below_max
    point = Anomonitor::MetricPoint.new(source: "sidekiq", metric: "queue_depth", value: 50)
    anomalies = Anomonitor::Detector.new.evaluate([point])
    assert_empty anomalies
  end

  def test_growth_spike_from_tags_previous
    point = Anomonitor::MetricPoint.new(
      source: "table:jobs",
      metric: "growth_rate",
      value: 90,
      tags: { previous: 20 }
    )
    anomalies = Anomonitor::Detector.new.evaluate([point])

    assert_equal 1, anomalies.size
    assert_equal "growth_spike", anomalies.first.rule
  end

  def test_cooldown_prevents_duplicate
    point = Anomonitor::MetricPoint.new(source: "sidekiq", metric: "queue_depth", value: 250)
    detector = Anomonitor::Detector.new

    first = detector.evaluate([point])
    second = detector.evaluate([point])

    assert_equal 1, first.size
    assert_empty second
  end
end
