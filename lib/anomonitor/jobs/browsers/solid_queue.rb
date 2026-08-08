# frozen_string_literal: true

module Anomonitor
  module Jobs
    module Browsers
      class SolidQueue
        LIMIT = 50

        def source_key
          "solid_queue"
        end

        def fetch(filters)
          unless solid_queue_available?
            Anomonitor.logger.warn("[Anomonitor] Jobs browser skipped solid_queue: tables not available")
            return []
          end

          status = filters[:status]
          rows = []
          rows.concat(ready_rows(filters)) if status == "all" || status == "pending"
          rows.concat(scheduled_rows(filters)) if status == "all" || status == "pending"
          rows.concat(claimed_rows(filters)) if status == "all" || status == "locked"
          rows.concat(failed_rows(filters)) if status == "all" || status == "failed"
          rows.first(LIMIT)
        rescue StandardError => e
          Anomonitor.logger.warn("[Anomonitor] Solid Queue jobs browser error: #{e.message}")
          []
        end

        private

        def solid_queue_available?
          return false unless defined?(ActiveRecord::Base)

          table_exists?("solid_queue_jobs")
        end

        def table_exists?(name)
          connection.data_source_exists?(name)
        rescue StandardError
          false
        end

        def connection
          ActiveRecord::Base.connection
        end

        def ready_rows(filters)
          return [] unless table_exists?("solid_queue_ready_executions")

          map_jobs(select_joined("solid_queue_ready_executions", filters), "pending")
        end

        def scheduled_rows(filters)
          return [] unless table_exists?("solid_queue_scheduled_executions")

          sql = <<~SQL.squish
            SELECT j.id, j.class_name, j.queue_name, j.created_at, j.scheduled_at,
                   e.scheduled_at AS exec_at
            FROM solid_queue_jobs j
            INNER JOIN solid_queue_scheduled_executions e ON e.job_id = j.id
            #{queue_clause(filters)}
            ORDER BY j.id DESC
            LIMIT #{LIMIT}
          SQL
          map_jobs(connection.select_all(sql), "pending")
        end

        def claimed_rows(filters)
          return [] unless table_exists?("solid_queue_claimed_executions")

          map_jobs(select_joined("solid_queue_claimed_executions", filters), "locked")
        end

        def failed_rows(filters)
          return [] unless table_exists?("solid_queue_failed_executions")

          sql = <<~SQL.squish
            SELECT j.id, j.class_name, j.queue_name, j.created_at, j.scheduled_at,
                   e.error, e.created_at AS failed_at
            FROM solid_queue_jobs j
            INNER JOIN solid_queue_failed_executions e ON e.job_id = j.id
            #{queue_clause(filters)}
            ORDER BY e.created_at DESC
            LIMIT #{LIMIT}
          SQL
          map_jobs(connection.select_all(sql), "failed")
        end

        def select_joined(exec_table, filters)
          sql = <<~SQL.squish
            SELECT j.id, j.class_name, j.queue_name, j.created_at, j.scheduled_at
            FROM solid_queue_jobs j
            INNER JOIN #{exec_table} e ON e.job_id = j.id
            #{queue_clause(filters)}
            ORDER BY j.id DESC
            LIMIT #{LIMIT}
          SQL
          connection.select_all(sql)
        end

        def queue_clause(filters)
          return "" unless filters[:queue]

          "WHERE j.queue_name = #{connection.quote(filters[:queue])}"
        end

        def map_jobs(result, status)
          result.map do |row|
            error = row["error"]
            error = error.to_s.lines.first&.strip if error
            run_at = parse_time(row["exec_at"] || row["scheduled_at"] || row["created_at"])
            failed_at = status == "failed" ? parse_time(row["failed_at"] || row["created_at"]) : nil

            Row.new(
              source: source_key,
              id: row["id"],
              name: row["class_name"].presence || "SolidQueue::Job",
              status: status,
              queue: row["queue_name"],
              tenant: nil,
              run_at: run_at,
              failed_at: failed_at,
              error: truncate(error),
              tags: {}
            )
          end
        end

        def parse_time(value)
          return nil if value.nil?
          return value if value.is_a?(Time) || value.is_a?(DateTime)

          Time.parse(value.to_s)
        rescue StandardError
          nil
        end

        def truncate(text, max = 200)
          return nil if text.nil?

          s = text.to_s
          s.length > max ? "#{s[0, max]}…" : s
        end
      end
    end
  end
end
