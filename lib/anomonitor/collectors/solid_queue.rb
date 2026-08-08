# frozen_string_literal: true

module Anomonitor
  module Collectors
    class SolidQueue < Base
      def collect
        unless solid_queue_available?
          log_skip("Solid Queue tables not available")
          return []
        end

        points = []
        points << count_point("claimed", "solid_queue_claimed_executions")
        points << count_point("failed", "solid_queue_failed_executions")
        points << count_point("scheduled", "solid_queue_scheduled_executions")

        if table_exists?("solid_queue_ready_executions")
          points << point(
            source: "solid_queue",
            metric: "queue_depth",
            value: connection.select_value("SELECT COUNT(*) FROM solid_queue_ready_executions").to_i
          )
        end

        points.compact
      rescue StandardError => e
        Anomonitor.logger.warn("[Anomonitor] Solid Queue collector error: #{e.message}")
        []
      end

      private

      def solid_queue_available?
        return false unless defined?(ActiveRecord::Base)

        table_exists?("solid_queue_ready_executions")
      end

      def table_exists?(name)
        connection.data_source_exists?(name)
      rescue StandardError
        false
      end

      def connection
        ActiveRecord::Base.connection
      end

      def count_point(metric, table)
        return nil unless table_exists?(table)

        value = connection.select_value("SELECT COUNT(*) FROM #{table}").to_i
        point(source: "solid_queue", metric: metric, value: value)
      end
    end
  end
end
