# frozen_string_literal: true

require "test_helper"

class AnomalyActionsTest < AnomonitorTestCase
  def setup
    super
    Anomonitor.configure do |c|
      c.notifier = ->(_a, event:) { true }
      c.cooldown = 1
      c.alert :missing_tables, max: 0
    end
  end

  def drifting_point(digest: "abc")
    Anomonitor::MetricPoint.new(
      source: "schema_drift",
      metric: "missing_tables",
      value: 2,
      tags: {
        tenant: "acme",
        items: "users,orders",
        items_list: %w[users orders],
        items_digest: digest,
        item_count: 2
      }
    )
  end

  def clear_point
    Anomonitor::MetricPoint.new(
      source: "schema_drift",
      metric: "missing_tables",
      value: 0,
      tags: { tenant: "acme", items: "", item_count: 0 }
    )
  end

  def test_manual_resolve_silences_until_clear
    detector = Anomonitor::Detector.new
    first = detector.evaluate([drifting_point])
    assert_equal 1, first.size

    first.first.resolve!(by: "manual", notify: true)
    assert first.first.manual_resolve?

    second = detector.evaluate([drifting_point])
    assert_empty second

    detector.evaluate([clear_point])
    first.first.reload
    assert first.first.cleared_after_ack?

    again = detector.evaluate([drifting_point])
    assert_equal 1, again.size
  end

  def test_reopen_allows_notification
    detector = Anomonitor::Detector.new
    first = detector.evaluate([drifting_point(digest: "reopen")])
    first.first.resolve!(by: "manual")
    assert_empty detector.evaluate([drifting_point(digest: "reopen")])

    first.first.reopen!
    again = detector.evaluate([drifting_point(digest: "reopen")])
    assert_equal 1, again.size
  end

  def test_retry_webhook
    anomaly = Anomonitor::Anomaly.create!(
      rule: "threshold",
      source: "sidekiq",
      metric: "queue_depth",
      value: 10,
      threshold: 1,
      severity: "high",
      cooldown_key: "retry:1",
      sampled_at: Time.current,
      webhook_status: "failed"
    )
    assert anomaly.retry_webhook!
    assert_equal "delivered", anomaly.reload.webhook_status
  end

  def test_items_list_prefers_full_array
    anomaly = Anomonitor::Anomaly.create!(
      rule: "threshold",
      source: "schema_drift",
      metric: "missing_tables",
      value: 3,
      threshold: 0,
      severity: "high",
      cooldown_key: "items:1",
      sampled_at: Time.current,
      tags: { "items" => "a,b", "items_list" => %w[a b c] }
    )
    assert_equal %w[a b c], anomaly.items_list
  end
end
