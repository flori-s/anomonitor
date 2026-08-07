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

  def test_delayed_job_style_per_tenant
    IndexJob.create!(tenant: "acme", run_at: 1.minute.ago, failed_at: nil, locked_at: nil, locked_by: nil)
    IndexJob.create!(tenant: "acme", run_at: 1.minute.ago, failed_at: Time.current, locked_at: nil, locked_by: nil)
    IndexJob.create!(tenant: "beta", run_at: 1.minute.ago, failed_at: nil, locked_at: Time.current, locked_by: "worker")

    Anomonitor.configure do |c|
      c.table :supp_jobs do |t|
        t.model = "IndexJob"
        t.style = :delayed_job
        t.tenant = :tenant
      end
    end

    source = Anomonitor.config.tables.first
    points = Anomonitor::Collectors::Table.new(source).collect

    acme_depth = points.find { |p| p.metric == "queue_depth" && p.tags[:tenant] == "acme" }
    beta_locked = points.find { |p| p.metric == "locked" && p.tags[:tenant] == "beta" }
    acme_failed = points.find { |p| p.metric == "failed" && p.tags[:tenant] == "acme" }

    assert_equal 1, acme_depth.value
    assert_equal 1, beta_locked.value
    assert_equal 1, acme_failed.value
  end
end
