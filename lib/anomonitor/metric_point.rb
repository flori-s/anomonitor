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
        digest = sticky_items_digest
        parts << digest if digest
      end
      parts.compact.join(":")
    end

    def sticky_items_digest
      digest = tags[:items_digest] || tags["items_digest"]
      return digest.to_s if digest && !digest.to_s.empty?

      items = tags[:items] || tags["items"]
      return nil if items.nil? || items.to_s.empty?

      Digest::SHA256.hexdigest(items.to_s)[0, 16]
    end
  end
end
