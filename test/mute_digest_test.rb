# frozen_string_literal: true

require "test_helper"

class MuteDigestTest < AnomonitorTestCase
  def test_mute_suppresses_anomaly
    Anomonitor.configure do |c|
      c.cooldown = 1
      c.alert :queue_depth, max: 10
      c.mute(metric: "queue_depth", source: "sidekiq", duration: 1.hour)
    end

    point = Anomonitor::MetricPoint.new(source: "sidekiq", metric: "queue_depth", value: 100)
    assert_empty Anomonitor::Detector.new.evaluate([point])
  end

  def test_alert_match_queue_tag
    Anomonitor.configure do |c|
      c.cooldown = 1
      c.alert :queue_depth, max: 10, match: { queue: true }
    end

    untagged = Anomonitor::MetricPoint.new(source: "sidekiq", metric: "queue_depth", value: 100)
    tagged = Anomonitor::MetricPoint.new(source: "sidekiq", metric: "queue_depth", value: 100, tags: { queue: "mailers" })

    detector = Anomonitor::Detector.new
    assert_empty detector.evaluate([untagged])
    assert_equal 1, detector.evaluate([tagged]).size
  end

  def test_digest_queues_then_flushes
    digests = []
    notifier = Object.new
    notifier.define_singleton_method(:deliver) { |_a, event: nil| true }
    notifier.define_singleton_method(:deliver_digest) do |payload|
      digests << payload
      true
    end

    Anomonitor.configure do |c|
      c.cooldown = 1
      c.digest_interval = 60
      c.digest_last_flushed_at = nil
      c.alert :queue_depth, max: 10
      c.notifier = notifier
    end

    point = Anomonitor::MetricPoint.new(source: "sidekiq", metric: "queue_depth", value: 100)
    anomalies = Anomonitor::Detector.new(notifier: notifier).evaluate([point])
    assert_equal 1, anomalies.size
    assert_equal "queued", anomalies.first.webhook_status

    Anomonitor::Digester.new(notifier: notifier).flush!
    assert_equal 1, digests.size
    assert_equal "anomaly.digest", digests.first[:event]
    assert_equal "delivered", anomalies.first.reload.webhook_status
  end

  def test_manual_resolve_sends_acked_event
    events = []
    Anomonitor.configure do |c|
      c.notifier = ->(_a, event:) { events << event; true }
    end

    anomaly = Anomonitor::Anomaly.create!(
      rule: "threshold",
      source: "sidekiq",
      metric: "queue_depth",
      value: 10,
      threshold: 1,
      severity: "high",
      cooldown_key: "ack:1",
      sampled_at: Time.current
    )
    anomaly.resolve!(by: "manual", notify: true)
    assert_equal ["anomaly.acked"], events
  end
end
