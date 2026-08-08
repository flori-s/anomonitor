# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"
ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "logger"
require "json"
require "active_support"
require "active_support/core_ext"
require "active_record"
require "minitest/autorun"

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "anomonitor/version"
require "anomonitor/configuration"
require "anomonitor/metric_point"
require "anomonitor/collectors/base"
require "anomonitor/collectors/sidekiq"
require "anomonitor/collectors/delayed_job"
require "anomonitor/collectors/solid_queue"
require "anomonitor/collectors/schema_drift"
require "anomonitor/collectors/table"
require "anomonitor/jobs/row"
require "anomonitor/jobs/browser"
require "anomonitor/jobs/browsers/sidekiq"
require "anomonitor/jobs/browsers/delayed_job"
require "anomonitor/jobs/browsers/solid_queue"
require "anomonitor/jobs/browsers/table"
require "anomonitor/tenancy"
require "anomonitor/notifiers/webhook"
require "anomonitor/detector"
require "anomonitor/poller"

module Anomonitor
  class << self
    def configure
      yield config
    end

    def config
      @config ||= Configuration.new
    end

    def reset_config!
      @config = Configuration.new
    end

    def logger
      @logger ||= Logger.new(File::NULL)
    end
  end
end

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Migration.verbose = false

ActiveRecord::Schema.define do
  create_table :anomonitor_metric_samples, force: true do |t|
    t.string :source, null: false
    t.string :metric, null: false
    t.float :value, null: false, default: 0
    t.text :tags
    t.datetime :sampled_at, null: false
    t.timestamps
  end

  create_table :anomonitor_anomalies, force: true do |t|
    t.string :rule, null: false
    t.string :source, null: false
    t.string :metric, null: false
    t.float :value, null: false
    t.float :threshold
    t.string :severity, null: false, default: "high"
    t.string :cooldown_key, null: false
    t.text :tags
    t.datetime :sampled_at
    t.string :webhook_status, default: "pending"
    t.datetime :webhook_delivered_at
    t.datetime :resolved_at
    t.timestamps
  end

  create_table :jobs, force: true do |t|
    t.string :status
    t.string :queue
    t.timestamps
  end

  create_table :index_jobs, force: true do |t|
    t.string :tenant
    t.string :queue
    t.datetime :run_at
    t.datetime :locked_at
    t.datetime :failed_at
    t.string :locked_by
  end
end

module Anomonitor
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
  end

  class MetricSample < ApplicationRecord
    self.table_name = "anomonitor_metric_samples"

    def tags
      raw = read_attribute(:tags)
      return {} if raw.nil? || raw == ""
      raw.is_a?(String) ? (JSON.parse(raw) rescue {}) : raw
    end

    def tags=(value)
      write_attribute(:tags, value.is_a?(String) ? value : JSON.generate(value || {}))
    end
  end

  class Anomaly < ApplicationRecord
    self.table_name = "anomonitor_anomalies"

    def tags
      raw = read_attribute(:tags)
      return {} if raw.nil? || raw == ""
      raw.is_a?(String) ? (JSON.parse(raw) rescue {}) : raw
    end

    def tags=(value)
      write_attribute(:tags, value.is_a?(String) ? value : JSON.generate(value || {}))
    end
  end
end

class Job < ActiveRecord::Base
  self.table_name = "jobs"
end

class IndexJob < ActiveRecord::Base
  self.table_name = "index_jobs"
end

class AnomonitorTestCase < Minitest::Test
  def setup
    Anomonitor.reset_config!
    Anomonitor.config.auto_start = false
    Anomonitor::MetricSample.delete_all
    Anomonitor::Anomaly.delete_all
    Job.delete_all
    IndexJob.delete_all
  end
end
