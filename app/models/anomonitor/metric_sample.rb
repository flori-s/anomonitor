# frozen_string_literal: true

module Anomonitor
  class MetricSample < ApplicationRecord
    self.table_name = "anomonitor_metric_samples"

    validates :source, :metric, :value, :sampled_at, presence: true

    INTERNAL_METRICS = %w[poll_tick].freeze

    scope :recent, ->(hours = 24) { where("sampled_at >= ?", hours.hours.ago) }
    scope :for_metric, ->(metric) { where(metric: metric) }
    scope :visible, -> { where.not(metric: INTERNAL_METRICS) }

    def self.latest_by_source_metric
      visible.recent(6).order(sampled_at: :desc).each_with_object({}) do |sample, hash|
        key = [sample.source, sample.metric, sample.tags]
        hash[key] ||= sample
      end.values
    end

    def self.series(source:, metric:, hours: 24)
      where(source: source, metric: metric)
        .where("sampled_at >= ?", hours.hours.ago)
        .order(:sampled_at)
    end
  end
end
