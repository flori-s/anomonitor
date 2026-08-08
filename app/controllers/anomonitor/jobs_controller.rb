# frozen_string_literal: true

module Anomonitor
  class JobsController < ApplicationController
    def index
      @status = Poller.instance.status.merge(poll_mode: Anomonitor.config.poll_mode)
      @filters = {
        source: params[:source].presence,
        status: params[:status].presence || "all",
        tenant: params[:tenant].presence,
        queue: params[:queue].presence
      }
      @sources = Jobs::Browser.enabled_sources
      @status_options = Jobs::Browser.status_options(@filters[:source])
      @filters[:status] = "all" unless @status_options.include?(@filters[:status])
      @health = build_health
      @jobs = Jobs::Browser.fetch(@filters)
    end

    private

    def build_health
      latest = MetricSample.latest_by_source_metric
      collectors = @status[:collectors] || @status["collectors"] || {}

      @sources.map do |source|
        metrics = latest.select { |s| s.source == source }
        by_metric = metrics.group_by(&:metric)
        collector_key = collector_status_key(source)
        collector = collectors[collector_key] || collectors[collector_key.to_s] || collectors[collector_key.to_sym]

        {
          source: source,
          collector: collector,
          queue_depth: metric_value(by_metric, "queue_depth"),
          failed: metric_value(by_metric, "failed") || metric_value(by_metric, "dead") || metric_value(by_metric, "retries"),
          locked: metric_value(by_metric, "locked") || metric_value(by_metric, "busy_workers") || metric_value(by_metric, "claimed"),
          series: MetricSample.series(source: source, metric: "queue_depth", hours: 24).last(48)
        }
      end
    end

    def metric_value(by_metric, name)
      rows = by_metric[name]
      return nil unless rows&.any?

      # Prefer untagged / aggregate sample when multiple tag variants exist
      preferred = rows.find { |s| s.tags.blank? || s.tags == {} } || rows.first
      preferred.value
    end

    def collector_status_key(source)
      if source.start_with?("table:")
        :"table_#{source.delete_prefix('table:')}"
      else
        source.to_sym
      end
    end
  end
end
