# frozen_string_literal: true

module Anomonitor
  class Configuration
    attr_accessor :webhook_url, :poll_interval, :cooldown, :retention_days,
                  :dashboard_path, :dashboard_base_url,
                  :tenants, :exclude_tenants, :tenant_switch,
                  :schema_drift_exclude, :schema_drift_interval,
                  :authenticate

    attr_reader :collectors, :tables, :alerts, :poll_mode, :auto_start

    def initialize
      @webhook_url = nil
      @poll_interval = 60
      @cooldown = 15 * 60
      @retention_days = 7
      @dashboard_path = "/anomonitor"
      @dashboard_base_url = nil
      @schema_drift_interval = 15 * 60
      @authenticate = nil
      @poll_mode = :thread
      @auto_start = true
      @collectors = CollectorsConfig.new
      @tables = []
      @alerts = []

      # Multi-tenancy: array or callable returning schema/tenant names
      @tenants = nil
      @exclude_tenants = %w[public]
      # Optional: ->(name, &block) { Apartment::Tenant.switch(name, &block) }
      # Default uses Apartment::Tenant.switch when available
      @tenant_switch = nil

      # Exact names or File.fnmatch globs skipped by schema drift
      @schema_drift_exclude = %w[
        schema_migrations
        ar_internal_metadata
        anomonitor_*
      ]
    end

    # Absolute URL prefix for webhook dashboard links, e.g. "https://ops.example.com"
    # Combined with dashboard_path. Falls back to path-only when blank.
    def anomaly_dashboard_url(anomaly_id)
      path = "#{dashboard_path.to_s.sub(%r{/+\z}, "")}/anomalies/#{anomaly_id}"
      path = "/#{path}" unless path.start_with?("/")
      base = dashboard_base_url.to_s.strip.sub(%r{/+\z}, "")
      base.empty? ? path : "#{base}#{path}"
    end

    # :thread — in-process background poller (default)
    # :cron   — no background thread; schedule `rails anomonitor:poll`
    def poll_mode=(mode)
      mode = mode.to_sym
      unless %i[thread cron].include?(mode)
        raise ArgumentError, "poll_mode must be :thread or :cron (got #{mode.inspect})"
      end

      @poll_mode = mode
      @auto_start = (mode == :thread)
    end

    # Legacy alias: auto_start=false is the same as poll_mode=:cron
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
      # style: :status (default) uses status/active columns
      # style: :delayed_job uses failed_at / locked_at / run_at like Delayed::Job
      # tenant: optional column name to emit per-tenant metrics (e.g. :tenant)
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
