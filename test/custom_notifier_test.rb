# frozen_string_literal: true

require "test_helper"

class CustomNotifierTest < AnomonitorTestCase
  def anomaly
    Anomonitor::Anomaly.create!(
      rule: "threshold",
      source: "sidekiq",
      metric: "queue_depth",
      value: 10,
      threshold: 5,
      severity: "high",
      cooldown_key: "custom:1",
      sampled_at: Time.current
    )
  end

  def test_callable_notifier_with_broadcast_style_hash
    calls = []
    Anomonitor.configure do |c|
      c.notifier = ->(a, event:) {
        calls << [a.id, event]
        { accepted: true, status_code: 200 }
      }
    end

    assert Anomonitor.config.build_notifier.deliver(anomaly, event: "anomaly.detected")
    assert_equal 1, calls.size
    assert_equal "anomaly.detected", calls.first.last
  end

  def test_object_notifier_deliver
    notifier = Object.new
    def notifier.deliver(anomaly, event: "anomaly.detected")
      true
    end

    Anomonitor.configure { |c| c.notifier = notifier }
    assert Anomonitor.config.build_notifier.deliver(anomaly)
  end

  def test_payload_helper
    a = anomaly
    payload = Anomonitor::Notifiers.payload(a, event: "anomaly.resolved")
    assert_equal "anomonitor", payload[:gem]
    assert_equal "anomaly.resolved", payload[:event]
    assert_equal a.id, a.id
    assert payload.key?(:dashboard_url)
  end

  def test_detector_uses_configured_notifier
    events = []
    Anomonitor.configure do |c|
      c.cooldown = 1
      c.alert :queue_depth, max: 100
      c.notifier = ->(_a, event:) { events << event; true }
    end

    point = Anomonitor::MetricPoint.new(source: "sidekiq", metric: "queue_depth", value: 250)
    Anomonitor::Detector.new.evaluate([point])
    assert_equal ["anomaly.detected"], events
  end
end
