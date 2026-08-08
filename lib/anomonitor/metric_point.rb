# frozen_string_literal: true

require "digest"

module Anomonitor
  MetricPoint = Struct.new(:source, :metric, :value, :tags, :sampled_at, keyword_init: true) do
    def initialize(source:, metric:, value:, tags: {}, sampled_at: Time.current)
      super(
        source: source.to_s,
        metric: metric.to_s,
        value: value.to_f,
        tags: tags || {},
        sampled_at: sampled_at
      )
    end

    def sticky?
      source == "schema_drift"
    end

    def cooldown_key
      tenant = tags[:tenant] || tags["tenant"]
      queue = tags[:queue] || tags["queue"]
      parts = [source, metric, tenant, queue]
      if sticky?
        items = tags[:items] || tags["items"]
        parts << Digest::SHA256.hexdigest(items.to_s)[0, 16] if items && !items.to_s.empty?
      end
      parts.compact.join(":")
    end
  end
end
