# frozen_string_literal: true

module Anomonitor
  module Notifiers
    DETECTED = "anomaly.detected"
    RESOLVED = "anomaly.resolved"

    module_function

    # Build the configured notifier (default: built-in Webhook).
    # Accepts a deliver-capable object, a Class, a callable, or an Array of those.
    def build(config = Anomonitor.config)
      raw = config.notifier
      return Webhook.new if raw.nil?

      list = Array(raw).map { |entry| wrap(entry) }
      list.size == 1 ? list.first : Composite.new(list)
    end

    def wrap(entry)
      case entry
      when Class
        entry.new
      else
        if entry.respond_to?(:deliver)
          entry
        elsif entry.respond_to?(:call)
          Callable.new(entry)
        else
          raise ArgumentError,
                "Anomonitor notifier must respond to #deliver or #call (got #{entry.class})"
        end
      end
    end

    # Shared JSON payload for custom transports (e.g. host Webhook::Broadcast).
    def payload(anomaly, event: DETECTED)
      {
        gem: "anomonitor",
        event: event.to_s,
        severity: anomaly.severity,
        rule: anomaly.rule,
        source: anomaly.source,
        metric: anomaly.metric,
        value: anomaly.value,
        threshold: anomaly.threshold,
        sampled_at: anomaly.sampled_at&.iso8601,
        resolved_at: anomaly.resolved_at&.iso8601,
        dashboard_url: Anomonitor.config.anomaly_dashboard_url(anomaly.id),
        tags: anomaly.tags
      }
    end
  end
end
