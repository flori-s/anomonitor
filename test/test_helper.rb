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
require "anomonitor/notifiers"
require "anomonitor/notifiers/callable"
require "anomonitor/notifiers/composite"
require "anomonitor/notifiers/webhook"
require "anomonitor/notifiers/rate_limited"
require "anomonitor/configuration_validator"
require "anomonitor/metrics_export"
require "anomonitor/poll_lock"
require "anomonitor/digester"
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

  create_table :anomonitor_mutes, force: true do |t|
    t.string :metric
    t.string :rule
    t.string :source
    t.string :tenant
    t.datetime :muted_until, null: false
    t.string :reason
    t.timestamps
  end
end

module Anomonitor
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
  end

  class MetricSample < ApplicationRecord
    self.table_name = "anomonitor_metric_samples"

    scope :recent, ->(hours = 24) { where("sampled_at >= ?", hours.hours.ago) }

    def self.latest_by_source_metric
      recent(6).order(sampled_at: :desc).each_with_object({}) do |sample, hash|
        key = [sample.source, sample.metric, sample.tags]
        hash[key] ||= sample
      end.values
    end

    def self.series(source:, metric:, hours: 24)
      where(source: source, metric: metric)
        .where("sampled_at >= ?", hours.hours.ago)
        .order(:sampled_at)
    end

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

    scope :recent, -> { order(created_at: :desc) }
    scope :open, -> { where(resolved_at: nil) }
    scope :resolved, -> { where.not(resolved_at: nil) }
    scope :webhook_failed, -> { where(webhook_status: "failed") }

    def open?
      resolved_at.nil?
    end

    def resolved?
      !open?
    end

    def webhook_failed?
      webhook_status.to_s == "failed"
    end

    def manual_resolve?
      tag_value("resolved_by").to_s == "manual"
    end

    def cleared_after_ack?
      tag_value("cleared_at").present?
    end

    def resolve!(by: "auto", notify: false)
      return self if resolved?

      merge_tags!("resolved_by" => by.to_s)
      update!(resolved_at: Time.current)
      if notify
        event = by.to_s == "manual" ? Anomonitor::Notifiers::ACKED : Anomonitor::Notifiers::RESOLVED
        Anomonitor.config.build_notifier.deliver(self, event: event)
      end
      self
    end

    def reopen!
      if open?
        merge_tags!("reopened_at" => Time.current.iso8601)
        save!
        return self
      end

      merge_tags!(
        "cleared_at" => Time.current.iso8601,
        "reopened_at" => Time.current.iso8601
      )
      save!
      self
    end

    def retry_webhook!
      delivered = Anomonitor.config.build_notifier.deliver(
        self,
        event: resolved? ? Anomonitor::Notifiers::RESOLVED : Anomonitor::Notifiers::DETECTED
      )
      update!(
        webhook_status: delivered ? "delivered" : "failed",
        webhook_delivered_at: delivered ? Time.current : webhook_delivered_at
      )
      delivered
    end

    def items_list
      list = tag_value("items_list")
      return Array(list) if list.is_a?(Array)

      items = tag_value("items")
      return [] if items.nil? || items.to_s.empty?

      items.to_s.split(",").map(&:strip)
    end

    def tag_value(key)
      t = tags
      return nil unless t.is_a?(Hash)

      t[key.to_s] || t[key.to_sym]
    end

    def merge_tags!(extra)
      current = tags.is_a?(Hash) ? tags.stringify_keys : {}
      extra.stringify_keys.each do |k, v|
        if v.nil?
          current.delete(k)
        else
          current[k] = v
        end
      end
      self.tags = current
    end

    def tags
      raw = read_attribute(:tags)
      return {} if raw.nil? || raw == ""
      raw.is_a?(String) ? (JSON.parse(raw) rescue {}) : raw
    end

    def tags=(value)
      write_attribute(:tags, value.is_a?(String) ? value : JSON.generate(value || {}))
    end
  end

  class Mute < ApplicationRecord
    self.table_name = "anomonitor_mutes"

    validates :muted_until, presence: true
    scope :active, -> { where("muted_until > ?", Time.current) }
    scope :recent, -> { order(muted_until: :desc) }

    def active?
      muted_until > Time.current
    end

    def matches?(anomaly_or_attrs)
      attrs =
        if anomaly_or_attrs.respond_to?(:metric)
          {
            metric: anomaly_or_attrs.metric,
            rule: anomaly_or_attrs.rule,
            source: anomaly_or_attrs.source,
            tenant: tenant_from(anomaly_or_attrs)
          }
        else
          anomaly_or_attrs
        end

      return false if metric.present? && metric.to_s != attrs[:metric].to_s
      return false if rule.present? && rule.to_s != attrs[:rule].to_s
      return false if source.present? && source.to_s != attrs[:source].to_s
      return false if tenant.present? && tenant.to_s != attrs[:tenant].to_s

      true
    end

    def self.muted?(anomaly_or_attrs)
      active.any? { |m| m.matches?(anomaly_or_attrs) }
    rescue StandardError
      false
    end

    def self.prune_expired!
      where("muted_until <= ?", Time.current).delete_all
    end

    private

    def tenant_from(anomaly)
      tags = anomaly.tags
      return nil unless tags.is_a?(Hash)

      tags["tenant"] || tags[:tenant]
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
    Anomonitor::Mute.delete_all
    Job.delete_all
    IndexJob.delete_all
  end
end
