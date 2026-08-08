# frozen_string_literal: true

require "test_helper"

class PollerPruneTest < AnomonitorTestCase
  def test_prunes_old_resolved_anomalies_but_keeps_open_schema_drift
    Anomonitor.configure { |c| c.retention_days = 7 }

    old_resolved = Anomonitor::Anomaly.create!(
      rule: "threshold",
      source: "schema_drift",
      metric: "missing_tables",
      value: 1,
      threshold: 0,
      severity: "high",
      cooldown_key: "old:resolved",
      sampled_at: 10.days.ago,
      resolved_at: 9.days.ago
    )
    open_drift = Anomonitor::Anomaly.create!(
      rule: "threshold",
      source: "schema_drift",
      metric: "missing_tables",
      value: 1,
      threshold: 0,
      severity: "high",
      cooldown_key: "old:open",
      sampled_at: 10.days.ago,
      resolved_at: nil
    )
    old_queue = Anomonitor::Anomaly.create!(
      rule: "threshold",
      source: "sidekiq",
      metric: "queue_depth",
      value: 100,
      threshold: 50,
      severity: "high",
      cooldown_key: "old:queue",
      sampled_at: 10.days.ago
    )

    [old_resolved, open_drift, old_queue].each do |row|
      row.update_columns(created_at: 10.days.ago, updated_at: 10.days.ago)
    end

    Anomonitor::Poller.instance.send(:prune_old_records)

    refute Anomonitor::Anomaly.exists?(old_resolved.id)
    refute Anomonitor::Anomaly.exists?(old_queue.id)
    assert Anomonitor::Anomaly.exists?(open_drift.id)
  end
end
