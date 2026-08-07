# frozen_string_literal: true

module Anomonitor
  module Collectors
    class DelayedJob < Base
      def collect
        unless defined?(::Delayed::Job)
          log_skip("Delayed::Job not loaded")
          return []
        end

        if Tenancy.multi_tenant?
          collect_per_tenant
        else
          metrics_for(nil)
        end
      rescue StandardError => e
        Anomonitor.logger.warn("[Anomonitor] Delayed Job collector error: #{e.message}")
        []
      end

      private

      def collect_per_tenant
        points = []
        Tenancy.tenant_names.each do |tenant|
          Tenancy.switch(tenant) do
            points.concat(metrics_for(tenant))
          end
        rescue StandardError => e
          Anomonitor.logger.warn("[Anomonitor] Delayed Job collector (#{tenant}) error: #{e.message}")
        end
        points
      end

      def metrics_for(tenant)
        scope = ::Delayed::Job
        now = Time.current
        tags = tenant ? { tenant: tenant } : {}

        pending = scope.where(failed_at: nil).where("run_at <= ?", now).where(locked_at: nil).count
        failed = scope.where.not(failed_at: nil).count
        locked = scope.where.not(locked_at: nil).where(failed_at: nil).count
        total = scope.count

        [
          point(source: "delayed_job", metric: "queue_depth", value: pending, tags: tags),
          point(source: "delayed_job", metric: "failed", value: failed, tags: tags),
          point(source: "delayed_job", metric: "locked", value: locked, tags: tags),
          point(source: "delayed_job", metric: "total", value: total, tags: tags)
        ]
      end
    end
  end
end
