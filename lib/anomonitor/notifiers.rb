# frozen_string_literal: true

module Anomonitor
  module Notifiers
    DETECTED = "anomaly.detected"
    RESOLVED = "anomaly.resolved"
    ACKED = "anomaly.acked"
    DIGEST = "anomaly.digest"

    module_function

    def build(config = Anomonitor.config)
      raw = config.notifier
      notifier =
        if raw.nil?
          Webhook.new
        else
          list = Array(raw).map { |entry| wrap(entry) }
          list.size == 1 ? list.first : Composite.new(list)
        end

      limit = config.notifier_rate_limit.to_i
      limit.positive? ? RateLimited.new(notifier, limit_per_minute: limit) : notifier
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
