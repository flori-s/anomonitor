# frozen_string_literal: true

module Anomonitor
  class Configuration
    attr_accessor :webhook_url, :poll_interval, :cooldown, :retention_days,
                  :dashboard_path, :dashboard_base_url,
                  :tenants, :exclude_tenants, :tenant_switch,
                  :schema_drift_exclude, :schema_drift_interval,
                  :authenticate, :notifier, :poll_lock,
                  :digest_interval, :digest_last_flushed_at, :notifier_rate_limit

    attr_reader :collectors, :tables, :alerts, :poll_mode, :auto_start

    def initialize
      @webhook_url = nil
      @notifier = nil
      @poll_interval = 60
      @cooldown = 15 * 60
      @retention_days = 7
      @dashboard_path = "/anomonitor"
      @dashboard_base_url = nil
      @schema_drift_interval = 15 * 60
      @authenticate = nil
      @poll_lock = true
      @digest_interval = nil
      @digest_last_flushed_at = nil
      @notifier_rate_limit = 0
      @poll_mode = :thread
      @auto_start = true
      @collectors = CollectorsConfig.new
      @tables = []
      @alerts = []

      @tenants = nil
      @exclude_tenants = %w[public]
      @tenant_switch = nil

      @schema_drift_exclude = %w[
        schema_migrations
        ar_internal_metadata
        anomonitor_*
      ]
    end

    def anomaly_dashboard_url(anomaly_id)
      path = "#{dashboard_path.to_s.sub(%r{/+\z}, "")}/anomalies/#{anomaly_id}"
      path = "/#{path}" unless path.start_with?("/")
      base = dashboard_base_url.to_s.strip.sub(%r{/+\z}, "")
      base.empty? ? path : "#{base}#{path}"
    end

    def build_notifier
      Notifiers.build(self)
    end

    def digest_enabled?
      digest_interval.to_i.positive?
    end

    # Persist a mute (DB) — metric/rule/source/tenant are optional matchers.
    # duration: seconds or ActiveSupport duration (e.g. 24.hours)
    def mute(duration:, metric: nil, rule: nil, source: nil, tenant: nil, reason: nil)
      seconds = duration.respond_to?(:to_i) ? duration.to_i : duration
      Mute.create!(
        metric: metric&.to_s,
        rule: rule&.to_s,
        source: source&.to_s,
        tenant: tenant&.to_s,
        muted_until: Time.current + seconds,
        reason: reason
      )
    end

    def poll_mode=(mode)
      mode = mode.to_sym
      unless %i[thread cron].include?(mode)
        raise ArgumentError, "poll_mode must be :thread or :cron (got #{mode.inspect})"
      end

      @poll_mode = mode
      @auto_start = (mode == :thread)
    end

    def auto_start=(value)
      @auto_start = !!value
      @poll_mode = @auto_start ? :thread : :cron
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
      attr_accessor :sidekiq, :delayed_job, :solid_queue, :schema_drift

      def initialize
        @sidekiq = true
        @delayed_job = true
        @solid_queue = true
        @schema_drift = false
      end
    end

    class TableSource
      attr_accessor :name, :model, :timestamp, :status, :active, :tenant, :style

      def initialize(name)
        @name = name
        @timestamp = :created_at
        @status = :status
        @active = %w[pending running]
        @tenant = nil
        @style = :status
      end

      def model_class
        model.to_s.constantize
      end

      def delayed_job_style?
        style.to_s == "delayed_job"
      end
    end

    class AlertRule
      attr_reader :metric, :max, :window, :multiplier, :severity, :match

      def initialize(metric, max: nil, window: nil, multiplier: nil, severity: "high", match: {})
        @metric = metric.to_sym
        @max = max
        @window = normalize_duration(window)
        @multiplier = multiplier
        @severity = severity
        @match = (match || {}).transform_keys(&:to_sym)
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

      # match: { queue: true } => tag present; { queue: nil } => tag absent; { queue: "x" } => exact
      def matches_point?(point)
        return true if match.nil? || match.empty?

        match.all? do |key, expected|
          tag = point.tags[key] || point.tags[key.to_s]
          case expected
          when true then !tag.nil? && tag.to_s != ""
          when false, nil then tag.nil? || tag.to_s == ""
          else
            tag.to_s == expected.to_s
          end
        end
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
