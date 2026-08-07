# frozen_string_literal: true

module Anomonitor
  class DashboardController < ApplicationController
    def show
      @status = Poller.instance.status.merge(poll_mode: Anomonitor.config.poll_mode)
      @latest_metrics = MetricSample.latest_by_source_metric.sort_by { |m| [m.source, m.metric] }
      @recent_anomalies = Anomaly.recent.limit(10)
      @series = build_series
    end

    private

    def build_series
      MetricSample.recent(24)
                  .order(:sampled_at)
                  .group_by { |s| [s.source, s.metric] }
                  .transform_values { |rows| rows.last(48) }
    end
  end
end
