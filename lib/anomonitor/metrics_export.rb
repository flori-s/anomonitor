# frozen_string_literal: true

module Anomonitor
  module MetricsExport
    module_function

    def json_payload
      latest = MetricSample.latest_by_source_metric
      open_count = Anomaly.open.count
      {
        gem: "anomonitor",
        version: Anomonitor::VERSION,
        sampled_at: Time.current.iso8601,
        open_anomalies: open_count,
        metrics: latest.map do |s|
          {
            source: s.source,
            metric: s.metric,
            value: s.value,
            tags: s.tags,
            sampled_at: s.sampled_at&.iso8601
          }
        end
      }
    end

    def prometheus_text
      lines = []
      lines << "# HELP anomonitor_open_anomalies Number of unresolved anomalies"
      lines << "# TYPE anomonitor_open_anomalies gauge"
      lines << "anomonitor_open_anomalies #{Anomaly.open.count}"

      lines << "# HELP anomonitor_metric Latest metric sample value"
      lines << "# TYPE anomonitor_metric gauge"
      MetricSample.latest_by_source_metric.each do |s|
        labels = { source: s.source, metric: s.metric }
        tags = s.tags.is_a?(Hash) ? s.tags : {}
        %w[tenant queue table].each do |key|
          val = tags[key] || tags[key.to_sym]
          labels[key] = val if val && !val.to_s.empty?
        end
        lines << "anomonitor_metric{#{prometheus_labels(labels)}} #{s.value.to_f}"
      end
      "#{lines.join("\n")}\n"
    end

    def prometheus_labels(hash)
      hash.map { |k, v| "#{k}=\"#{escape_label(v)}\"" }.join(",")
    end

    def escape_label(value)
      value.to_s.gsub("\\", "\\\\").gsub("\n", "\\n").gsub('"', '\\"')
    end
  end
end
