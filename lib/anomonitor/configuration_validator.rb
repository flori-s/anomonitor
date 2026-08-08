# frozen_string_literal: true

module Anomonitor
  class ConfigurationValidator
    def self.warnings(config = Anomonitor.config)
      new(config).warnings
    end

    def initialize(config)
      @config = config
    end

    def warnings
      list = []
      if @config.notifier.nil? && @config.webhook_url.to_s.strip.empty?
        list << "No notifier configured (set c.webhook_url or c.notifier) — anomalies will record as webhook failed"
      end
      if @config.collectors.schema_drift
        tenants = begin
          Tenancy.tenant_names
        rescue StandardError
          []
        end
        if tenants.size < 2
          list << "schema_drift is enabled but fewer than 2 tenants are configured"
        end
      end
      if @config.poll_mode == :thread
        list << "poll_mode=:thread can double-collect under multi-worker Puma/Unicorn — prefer :cron or enable poll_lock"
      end
      path = @config.dashboard_path.to_s
      list << "dashboard_path should start with / (got #{path.inspect})" if path != "" && !path.start_with?("/")
      list
    end

    def log!
      warnings.each { |w| Anomonitor.logger.warn("[Anomonitor] Config: #{w}") }
    end
  end
end
