# frozen_string_literal: true

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

    def cooldown_key
      tenant = tags[:tenant] || tags["tenant"]
      queue = tags[:queue] || tags["queue"]
      [source, metric, tenant, queue].compact.join(":")
    end
  end
end
