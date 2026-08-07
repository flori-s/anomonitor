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
      queue = tags[:queue] || tags["queue"]
      [source, metric, queue].compact.join(":")
    end
  end
end
