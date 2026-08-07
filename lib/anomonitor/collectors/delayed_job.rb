# frozen_string_literal: true

module Anomonitor
  module Collectors
    class DelayedJob < Base
      def collect
        unless defined?(::Delayed::Job)
          log_skip("Delayed::Job not loaded")
          return []
        end

        scope = ::Delayed::Job
        now = Time.current

        pending = scope.where(failed_at: nil).where("run_at <= ?", now).where(locked_at: nil).count
        failed = scope.where.not(failed_at: nil).count
        locked = scope.where.not(locked_at: nil).where(failed_at: nil).count
        total = scope.count

        [
          point(source: "delayed_job", metric: "queue_depth", value: pending),
          point(source: "delayed_job", metric: "failed", value: failed),
          point(source: "delayed_job", metric: "locked", value: locked),
          point(source: "delayed_job", metric: "total", value: total)
        ]
      rescue StandardError => e
        Anomonitor.logger.warn("[Anomonitor] Delayed Job collector error: #{e.message}")
        []
      end
    end
  end
end
