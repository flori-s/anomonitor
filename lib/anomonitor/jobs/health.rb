# frozen_string_literal: true

module Anomonitor
  module Jobs
    # Collector health cards for the Jobs dashboard.
    # Uses persisted samples so cron poll (`rails anomonitor:poll`) works
    # the same as the in-process thread poller.
    class Health
      def self.cards(sources:, status:)
        new(sources: sources, status: status).cards
      end

      def initialize(sources:, status:)
        @sources = Array(sources)
        @status = status || {}
        @latest = defined?(MetricSample) ? MetricSample.latest_by_source_metric : []
        @collectors = @status[:collectors] || @status["collectors"] || {}
      end

      def cards
        @sources.map { |source| card_for(source) }
      end

      private

      def card_for(source)
        metrics = @latest.select { |s| s.source.to_s == source.to_s }
        by_metric = metrics.group_by(&:metric)
        collector = collector_for(source)

        {
          source: source,
          collector: collector,
          queue_depth: metric_value(by_metric, "queue_depth"),
          scheduled: metric_value(by_metric, "scheduled"),
          failed: metric_value(by_metric, "failed") || metric_value(by_metric, "dead") || metric_value(by_metric, "retries"),
          locked: metric_value(by_metric, "locked") || metric_value(by_metric, "busy_workers") || metric_value(by_metric, "claimed"),
          series: series_for(source),
          polled_at: collector && (collector[:at] || collector["at"])
        }
      end

      def collector_for(source)
        key = CollectorStatus.collector_key(source)
        @collectors[key] || @collectors[key.to_s] || @collectors[key.to_sym]
      end

      def metric_value(by_metric, name)
        rows = by_metric[name] || by_metric[name.to_s]
        return nil unless rows&.any?

        aggregates = rows.select { |s| tenant_of(s).blank? }
        chosen = aggregates.any? ? aggregates : rows
        chosen.sum { |s| s.value.to_f }
      end

      def series_for(source)
        return [] unless defined?(MetricSample)

        rows = MetricSample.series(source: source, metric: "queue_depth", hours: 24)
        aggregates = rows.select { |s| tenant_of(s).blank? }
        (aggregates.any? ? aggregates : rows).last(48)
      end

      def tenant_of(sample)
        tags = sample.tags
        return nil unless tags.is_a?(Hash)

        tags["tenant"] || tags[:tenant]
      end
    end
  end
end
