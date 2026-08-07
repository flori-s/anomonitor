# frozen_string_literal: true

module Anomonitor
  class Configuration
    attr_accessor :webhook_url, :poll_interval, :cooldown, :retention_days,
                  :dashboard_path, :auto_start

    attr_reader :collectors, :tables, :alerts

    def initialize
      @webhook_url = nil
      @poll_interval = 60
      @cooldown = 15 * 60
      @retention_days = 7
      @dashboard_path = "/anomonitor"
      @auto_start = true
      @collectors = CollectorsConfig.new
      @tables = []
      @alerts = []
    end

    def table(name, &block)
      source = TableSource.new(name)
      yield source if block_given?
      @tables << source
      source
    end

    def alert(metric, **options)
      rule = AlertRule.new(metric, **options)
      @alerts << rule
      rule
    end

    class CollectorsConfig
      attr_accessor :sidekiq, :delayed_job, :solid_queue

      def initialize
        @sidekiq = true
        @delayed_job = true
        @solid_queue = true
      end
    end

    class TableSource
      attr_accessor :name, :model, :timestamp, :status, :active

      def initialize(name)
        @name = name
        @timestamp = :created_at
        @status = :status
        @active = %w[pending running]
      end

      def model_class
        model.to_s.constantize
      end
    end

    class AlertRule
      attr_reader :metric, :max, :window, :multiplier, :severity

      def initialize(metric, max: nil, window: nil, multiplier: nil, severity: "high")
        @metric = metric.to_sym
        @max = max
        @window = normalize_duration(window)
        @multiplier = multiplier
        @severity = severity
      end

      def threshold?
        !max.nil?
      end

      def spike?
        !multiplier.nil?
      end

      def window_seconds
        @window || (5 * 60)
      end

      private

      def normalize_duration(value)
        return nil if value.nil?
        return value if value.is_a?(Numeric)
        return value.to_i if value.respond_to?(:to_i) && !value.is_a?(String)

        value
      end
    end
  end
end
