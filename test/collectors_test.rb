# frozen_string_literal: true

require "test_helper"

class SidekiqCollectorTest < AnomonitorTestCase
  def test_returns_empty_when_sidekiq_missing
    points = Anomonitor::Collectors::Sidekiq.new.collect
    assert_equal [], points
  end
end

class DelayedJobCollectorTest < AnomonitorTestCase
  def test_returns_empty_when_delayed_job_missing
    points = Anomonitor::Collectors::DelayedJob.new.collect
    assert_equal [], points
  end
end

class SolidQueueCollectorTest < AnomonitorTestCase
  def test_returns_empty_when_tables_missing
    points = Anomonitor::Collectors::SolidQueue.new.collect
    assert_equal [], points
  end
end
