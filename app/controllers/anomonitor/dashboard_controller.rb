# frozen_string_literal: true

module Anomonitor
  class DashboardController < ApplicationController
    def show
      @status = Poller.instance.status.merge(poll_mode: Anomonitor.config.poll_mode)
      @tenant = params[:tenant].presence
      @tenants = available_tenants
      @latest_metrics = filter_by_tenant(MetricSample.latest_by_source_metric)
                         .sort_by { |m| [m.source, m.metric] }
      @recent_anomalies = filter_anomalies(Anomaly.open.recent.limit(50)).first(10)
      @series = build_series
      @by_tenant = group_metrics_by_tenant(@latest_metrics) if @tenant.nil?
    end

    private

    def available_tenants
      MetricSample.recent(24).limit(500).filter_map do |s|
        tags = s.tags
        next unless tags.is_a?(Hash)

        tags["tenant"] || tags[:tenant]
      end.uniq.sort
    rescue StandardError
      []
    end

    def filter_by_tenant(samples)
      return samples unless @tenant

      samples.select do |s|
        tags = s.tags
        tags.is_a?(Hash) && (tags["tenant"] || tags[:tenant]).to_s == @tenant
      end
    end

    def filter_anomalies(scope)
      return scope.to_a unless @tenant

      scope.select do |a|
        tags = a.tags
        tags.is_a?(Hash) && (tags["tenant"] || tags[:tenant]).to_s == @tenant
      end
    end

    def group_metrics_by_tenant(samples)
      grouped = Hash.new { |h, k| h[k] = [] }
      samples.each do |s|
        tags = s.tags.is_a?(Hash) ? s.tags : {}
        key = tags["tenant"] || tags[:tenant] || "(untagged)"
        grouped[key] << s
      end
      grouped.sort_by { |k, _| k.to_s }.to_h
    end

    def build_series
      rows = MetricSample.recent(24).order(:sampled_at)
      if @tenant
        rows = rows.select do |s|
          tags = s.tags
          tags.is_a?(Hash) && (tags["tenant"] || tags[:tenant]).to_s == @tenant
        end
      end
      rows.group_by { |s| [s.source, s.metric] }
          .transform_values { |list| list.last(48) }
    end
  end
end
