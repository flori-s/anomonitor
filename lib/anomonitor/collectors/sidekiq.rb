# frozen_string_literal: true

module Anomonitor
  module Collectors
    class Sidekiq < Base
      def collect
        unless defined?(::Sidekiq)
          log_skip("Sidekiq not loaded")
          return []
        end

        stats = ::Sidekiq::Stats.new
        points = []

        points << point(source: "sidekiq", metric: "queue_depth", value: stats.enqueued)
        points << point(source: "sidekiq", metric: "busy_workers", value: stats.workers_size)
        points << point(source: "sidekiq", metric: "retries", value: stats.retry_size)
        points << point(source: "sidekiq", metric: "dead", value: stats.dead_size)
        points << point(source: "sidekiq", metric: "failed", value: stats.failed)
        points << point(source: "sidekiq", metric: "processed", value: stats.processed)

        ::Sidekiq::Queue.all.each do |queue|
          points << point(
            source: "sidekiq",
            metric: "queue_depth",
            value: queue.size,
            tags: { queue: queue.name }
          )

          if queue.respond_to?(:latency)
            points << point(
              source: "sidekiq",
              metric: "latency",
              value: queue.latency,
              tags: { queue: queue.name }
            )
          end
        end

        points
      rescue StandardError => e
        Anomonitor.logger.warn("[Anomonitor] Sidekiq collector error: #{e.message}")
        []
      end
    end
  end
end
