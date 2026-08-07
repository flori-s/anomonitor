# frozen_string_literal: true

require "test_helper"

class TableCollectorTest < AnomonitorTestCase
  def test_collects_active_and_growth
    Job.create!(status: "pending", created_at: Time.current)
    Job.create!(status: "running", created_at: Time.current)
    Job.create!(status: "done", created_at: 1.hour.ago)

    Anomonitor.configure do |c|
      c.alert :growth_spike, window: 300, multiplier: 3.0
      c.table :customer_jobs do |t|
        t.model = "Job"
        t.timestamp = :created_at
        t.status = :status
        t.active = %w[pending running]
      end
    end

    source = Anomonitor.config.tables.first
    points = Anomonitor::Collectors::Table.new(source).collect

    active = points.find { |p| p.metric == "active" }
    assert_equal 2, active.value

    growth = points.find { |p| p.metric == "growth_rate" }
    assert growth
    assert_equal 2, growth.value
  end
end
