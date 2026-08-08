# frozen_string_literal: true

require "singleton"

module Anomonitor
  class Poller
    include Singleton

    attr_reader :last_run_at, :last_error, :running

    def initialize
      @mutex = Mutex.new
      @thread = nil
      @running = false
      @last_run_at = nil
      @last_error = nil
      @collector_status = {}
      @last_schema_drift_at = nil
    end

    def start
      @mutex.synchronize do
        return if @running

        @running = true
        @thread = Thread.new { loop_poll }
        @thread.abort_on_exception = false
        Anomonitor.logger.info("[Anomonitor] Poller started (interval=#{Anomonitor.config.poll_interval}s)")
      end
    end

    def stop
      @mutex.synchronize do
        @running = false
        @thread&.kill
        @thread = nil
      end
    end

    def tick
      points = collect_all
      persist(points)
      Detector.new.evaluate(points)
      prune_old_records
      @last_run_at = Time.current
      @last_error = nil
      points
    rescue StandardError => e
      @last_error = e.message
      Anomonitor.logger.warn("[Anomonitor] Poller tick failed: #{e.message}")
      []
    end

    def status
      {
        poll_mode: Anomonitor.config.poll_mode,
        running: @running,
        last_run_at: effective_last_run_at,
        last_error: @last_error,
        collectors: @collector_status,
        poll_interval: Anomonitor.config.poll_interval,
        schema_drift_interval: Anomonitor.config.schema_drift_interval
      }
    end

    private

    def effective_last_run_at
      return @last_run_at if @last_run_at
      return nil unless defined?(Anomonitor::MetricSample)

      Anomonitor::MetricSample.maximum(:sampled_at)
    rescue StandardError
      nil
    end

    def loop_poll
      while @running
        tick
        sleep Anomonitor.config.poll_interval.to_i
      end
    end

    def collect_all
      points = []
      collectors.each do |name, collector|
        result = Array(collector.collect)
        @collector_status[name] = { ok: true, count: result.size, at: Time.current }
        @last_schema_drift_at = Time.current if name == :schema_drift
        points.concat(result)
      rescue StandardError => e
        @collector_status[name] = { ok: false, error: e.message, at: Time.current }
        Anomonitor.logger.warn("[Anomonitor] Collector #{name} failed: #{e.message}")
      end
      points
    end

    def collectors
      list = {}
      cfg = Anomonitor.config.collectors
      list[:sidekiq] = Collectors::Sidekiq.new if cfg.sidekiq
      list[:delayed_job] = Collectors::DelayedJob.new if cfg.delayed_job
      list[:solid_queue] = Collectors::SolidQueue.new if cfg.solid_queue
      list[:schema_drift] = Collectors::SchemaDrift.new if cfg.schema_drift && schema_drift_due?
      Anomonitor.config.tables.each do |table|
        list[:"table_#{table.name}"] = Collectors::Table.new(table)
      end
      list
    end

    def schema_drift_due?
      interval = Anomonitor.config.schema_drift_interval.to_i
      interval = Anomonitor.config.poll_interval.to_i if interval <= 0
      return true if @last_schema_drift_at.nil?

      Time.current - @last_schema_drift_at >= interval
    end

    def persist(points)
      return if points.empty?
      return unless defined?(Anomonitor::MetricSample)

      rows = points.map do |p|
        {
          source: p.source,
          metric: p.metric,
          value: p.value,
          tags: p.tags,
          sampled_at: p.sampled_at,
          created_at: Time.current,
          updated_at: Time.current
        }
      end
      Anomonitor::MetricSample.insert_all(rows)
    rescue StandardError => e
      Anomonitor.logger.warn("[Anomonitor] Failed to persist metrics: #{e.message}")
    end

    def prune_old_records
      days = Anomonitor.config.retention_days.to_i
      return if days <= 0

      cutoff = days.days.ago
      Anomonitor::MetricSample.where("sampled_at < ?", cutoff).delete_all
      # Keep open schema-drift anomalies until resolved; prune everything else by age
      Anomonitor::Anomaly
        .where("created_at < ?", cutoff)
        .where("NOT (source = ? AND resolved_at IS NULL)", "schema_drift")
        .delete_all
    rescue StandardError
      nil
    end
  end
end
