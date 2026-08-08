# frozen_string_literal: true

require "test_helper"

# Lightweight stand-ins for engine controller filter logic (no full Rails app).
class AnomaliesFilterTest < AnomonitorTestCase
  def test_open_and_resolved_scopes
    open_row = Anomonitor::Anomaly.create!(
      rule: "threshold",
      source: "schema_drift",
      metric: "missing_tables",
      value: 1,
      threshold: 0,
      severity: "high",
      cooldown_key: "filter:open",
      sampled_at: Time.current
    )
    resolved_row = Anomonitor::Anomaly.create!(
      rule: "threshold",
      source: "schema_drift",
      metric: "missing_tables",
      value: 1,
      threshold: 0,
      severity: "high",
      cooldown_key: "filter:resolved",
      sampled_at: Time.current,
      resolved_at: Time.current
    )

    assert_includes Anomonitor::Anomaly.open, open_row
    refute_includes Anomonitor::Anomaly.open, resolved_row
    assert_includes Anomonitor::Anomaly.resolved, resolved_row
  end
end
