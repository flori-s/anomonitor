# frozen_string_literal: true

require "test_helper"

class JobsBrowserTest < AnomonitorTestCase
  def test_enabled_sources_respects_config
    Anomonitor.configure do |c|
      c.collectors.sidekiq = true
      c.collectors.delayed_job = false
      c.collectors.solid_queue = false
      c.table :customer_jobs do |t|
        t.model = "Job"
      end
    end

    sources = Anomonitor::Jobs::Browser.enabled_sources
    assert_includes sources, "sidekiq"
    assert_includes sources, "table:customer_jobs"
    refute_includes sources, "delayed_job"
    refute_includes sources, "solid_queue"
  end

  def test_sidekiq_and_solid_queue_noop_when_unavailable
    Anomonitor.configure do |c|
      c.collectors.sidekiq = true
      c.collectors.delayed_job = false
      c.collectors.solid_queue = true
    end

    rows = Anomonitor::Jobs::Browser.fetch(status: "all")
    assert_equal [], rows
  end

  def test_table_delayed_job_style_filters
    IndexJob.create!(tenant: "acme", queue: "default", run_at: 2.minutes.ago, failed_at: nil, locked_at: nil, locked_by: nil)
    IndexJob.create!(tenant: "acme", queue: "mailers", run_at: 1.minute.ago, failed_at: Time.current, locked_at: nil, locked_by: nil)
    IndexJob.create!(tenant: "beta", queue: "default", run_at: 1.minute.ago, failed_at: nil, locked_at: Time.current, locked_by: "worker")

    Anomonitor.configure do |c|
      c.collectors.sidekiq = false
      c.collectors.delayed_job = false
      c.collectors.solid_queue = false
      c.table :supp_jobs do |t|
        t.model = "IndexJob"
        t.style = :delayed_job
        t.tenant = :tenant
      end
    end

    all = Anomonitor::Jobs::Browser.fetch(status: "all")
    assert_equal 3, all.size
    assert(all.all? { |r| r.source == "table:supp_jobs" })

    failed = Anomonitor::Jobs::Browser.fetch(status: "failed")
    assert_equal 1, failed.size
    assert_equal "failed", failed.first.status

    locked = Anomonitor::Jobs::Browser.fetch(status: "locked")
    assert_equal 1, locked.size
    assert_equal "beta", locked.first.tenant

    pending = Anomonitor::Jobs::Browser.fetch(status: "pending")
    assert_equal 1, pending.size
    assert_equal "pending", pending.first.status

    acme = Anomonitor::Jobs::Browser.fetch(status: "all", tenant: "acme")
    assert_equal 2, acme.size

    mailers = Anomonitor::Jobs::Browser.fetch(status: "all", queue: "mailers")
    assert_equal 1, mailers.size
    assert_equal "mailers", mailers.first.queue
  end

  def test_delayed_job_style_pending_excludes_future_run_at
    IndexJob.create!(tenant: "acme", queue: "default", run_at: 1.hour.from_now, failed_at: nil, locked_at: nil, locked_by: nil)
    IndexJob.create!(tenant: "acme", queue: "default", run_at: 1.minute.ago, failed_at: nil, locked_at: nil, locked_by: nil)

    Anomonitor.configure do |c|
      c.collectors.sidekiq = false
      c.collectors.delayed_job = false
      c.collectors.solid_queue = false
      c.table :supp_jobs do |t|
        t.model = "IndexJob"
        t.style = :delayed_job
        t.tenant = :tenant
      end
    end

    pending = Anomonitor::Jobs::Browser.fetch(status: "pending")
    assert_equal 1, pending.size
  end

  def test_status_options_hide_locked_for_status_style_tables
    Anomonitor.configure do |c|
      c.table :customer_jobs do |t|
        t.model = "Job"
        t.status = :status
        t.active = %w[pending running]
      end
      c.table :supp_jobs do |t|
        t.model = "IndexJob"
        t.style = :delayed_job
      end
    end

    assert_equal %w[all pending failed], Anomonitor::Jobs::Browser.status_options("table:customer_jobs")
    assert_equal %w[all pending failed locked], Anomonitor::Jobs::Browser.status_options("table:supp_jobs")
    assert_equal %w[all pending failed locked], Anomonitor::Jobs::Browser.status_options("sidekiq")
  end

  def test_table_status_style_filters
    Job.create!(status: "pending", created_at: Time.current)
    Job.create!(status: "running", created_at: Time.current)
    Job.create!(status: "failed", created_at: 1.hour.ago)
    Job.create!(status: "done", created_at: 2.hours.ago)

    Anomonitor.configure do |c|
      c.collectors.sidekiq = false
      c.collectors.delayed_job = false
      c.collectors.solid_queue = false
      c.table :customer_jobs do |t|
        t.model = "Job"
        t.timestamp = :created_at
        t.status = :status
        t.active = %w[pending running]
      end
    end

    pending = Anomonitor::Jobs::Browser.fetch(status: "pending")
    assert_equal 2, pending.size
    assert(pending.all? { |r| r.status == "pending" })

    failed = Anomonitor::Jobs::Browser.fetch(status: "failed")
    assert_equal 1, failed.size
    assert_equal "failed", failed.first.status

    locked = Anomonitor::Jobs::Browser.fetch(status: "locked")
    assert_equal [], locked
  end

  def test_source_filter_limits_to_one_adapter
    IndexJob.create!(tenant: "acme", run_at: 1.minute.ago, failed_at: nil, locked_at: nil, locked_by: nil)
    Job.create!(status: "pending", created_at: Time.current)

    Anomonitor.configure do |c|
      c.collectors.sidekiq = false
      c.collectors.delayed_job = false
      c.collectors.solid_queue = false
      c.table :supp_jobs do |t|
        t.model = "IndexJob"
        t.style = :delayed_job
        t.tenant = :tenant
      end
      c.table :customer_jobs do |t|
        t.model = "Job"
        t.status = :status
        t.active = %w[pending running]
      end
    end

    rows = Anomonitor::Jobs::Browser.fetch(source: "table:supp_jobs", status: "all")
    assert_equal 1, rows.size
    assert_equal "table:supp_jobs", rows.first.source
  end
end
