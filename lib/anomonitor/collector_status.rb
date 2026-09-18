# frozen_string_literal: true

module Anomonitor
  # In-process collector status is lost after `rails anomonitor:poll`.
  # Each tick also persists a `poll_tick` sample so cron-mode web processes
  # can reconstruct health (Jobs page "collector ok" vs "no poll yet").
  module CollectorStatus
    METRIC = "poll_tick"

    module_function

    def source_name(collector_key)
      name = collector_key.to_s
      return "table:#{name.delete_prefix('table_')}" if name.start_with?("table_")

      name
    end

    def collector_key(source)
      source = source.to_s
      return :"table_#{source.delete_prefix('table:')}" if source.start_with?("table:")

      source.to_sym
    end

    def heartbeat_point(collector_key, status)
      tags = { "count" => status[:count].to_i }
      tags["error"] = status[:error].to_s if status[:error].present?

      MetricPoint.new(
        source: source_name(collector_key),
        metric: METRIC,
        value: status[:ok] ? 1.0 : 0.0,
        tags: tags
      )
    end

    def snapshot(in_memory)
      return in_memory if in_memory.present?

      from_samples
    end

    def from_samples
      return {} unless defined?(Anomonitor::MetricSample)

      Anomonitor::MetricSample.where(metric: METRIC)
                              .recent(6)
                              .order(sampled_at: :desc)
                              .each_with_object({}) do |sample, hash|
        key = collector_key(sample.source)
        next if hash.key?(key)

        tags = sample.tags.is_a?(Hash) ? sample.tags : {}
        hash[key] = {
          ok: sample.value.to_f.positive?,
          count: (tags["count"] || tags[:count]).to_i,
          at: sample.sampled_at,
          error: tags["error"] || tags[:error]
        }
      end
    rescue StandardError
      {}
    end
  end
end
