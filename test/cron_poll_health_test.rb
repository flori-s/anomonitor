# frozen_string_literal: true

require "test_helper"

class CronPollHealthTest < AnomonitorTestCase
  def configure_table!
    Anomonitor.configure do |c|
      c.poll_mode = :cron
      c.collectors.sidekiq = false
      c.collectors.delayed_job = false
      c.collectors.solid_queue = false
      c.collectors.schema_drift = false
      c.table :supp_jobs do |t|
        t.model = "IndexJob"
        t.style = :delayed_job
        t.tenant = :tenant
      end
    end
  end

  def test_poll_tick_survives_process_reset_like_cron
    configure_table!
    IndexJob.create!(tenant: "acme", run_at: 1.minute.ago, failed_at: nil, locked_at: nil, locked_by: nil)

    points = Anomonitor::Poller.instance.tick
    assert points.any? { |p| p.metric == "poll_tick" && p.source == "table:supp_jobs" }
    assert Anomonitor::MetricSample.exists?(source: "table:supp_jobs", metric: "poll_tick")

    # New web process: in-memory collector status is empty
    Anomonitor::Poller.instance.reset!

    status = Anomonitor::Poller.instance.status
    collector = status[:collectors][:table_supp_jobs]
    assert collector, "expected reconstructed collector status from samples"
    assert_equal true, collector[:ok]
    assert collector[:at]
  end

  def test_jobs_health_cards_use_persisted_samples_after_cron
    configure_table!
    IndexJob.create!(tenant: "acme", run_at: 1.minute.ago, failed_at: nil, locked_at: nil, locked_by: nil)
    IndexJob.create!(tenant: "acme", run_at: 2.hours.from_now, failed_at: nil, locked_at: nil, locked_by: nil)

    Anomonitor::Poller.instance.tick
    Anomonitor::Poller.instance.reset!

    status = Anomonitor::Poller.instance.status.merge(poll_mode: :cron)
    cards = Anomonitor::Jobs::Health.cards(sources: ["table:supp_jobs"], status: status)
    card = cards.first

    assert_equal "table:supp_jobs", card[:source]
    assert_equal true, card[:collector][:ok]
    assert_equal 1, card[:queue_depth]
    assert_equal 1, card[:scheduled]
    assert_equal 0, card[:failed]
    assert_equal 0, card[:locked]
    assert card[:polled_at]
  end

  def test_jobs_health_sums_per_tenant_when_no_aggregate
    Anomonitor::MetricSample.create!(
      source: "table:supp_jobs",
      metric: "queue_depth",
      value: 2,
      tags: { "tenant" => "acme", "table" => "supp_jobs" },
      sampled_at: Time.current
    )
    Anomonitor::MetricSample.create!(
      source: "table:supp_jobs",
      metric: "queue_depth",
      value: 3,
      tags: { "tenant" => "beta", "table" => "supp_jobs" },
      sampled_at: Time.current
    )
    Anomonitor::MetricSample.create!(
      source: "table:supp_jobs",
      metric: "poll_tick",
      value: 1,
      tags: { "count" => 2 },
      sampled_at: Time.current
    )

    status = Anomonitor::Poller.instance.status
    cards = Anomonitor::Jobs::Health.cards(sources: ["table:supp_jobs"], status: status)
    assert_equal 5, cards.first[:queue_depth]
    assert_equal true, cards.first[:collector][:ok]
  end

  def test_no_poll_yet_without_samples
    configure_table!
    status = Anomonitor::Poller.instance.status.merge(poll_mode: :cron)
    cards = Anomonitor::Jobs::Health.cards(sources: ["table:supp_jobs"], status: status)
    collector = cards.first[:collector] || {}
    ok = collector[:ok].nil? ? collector["ok"] : collector[:ok]
    assert_nil ok
    assert_nil cards.first[:queue_depth]
  end
end
