# frozen_string_literal: true

module Anomonitor
  module Jobs
    module Browsers
      class Sidekiq
        PER_SET = 50

        def source_key
          "sidekiq"
        end

        def fetch(filters)
          unless defined?(::Sidekiq)
            Anomonitor.logger.warn("[Anomonitor] Jobs browser skipped sidekiq: Sidekiq not loaded")
            return []
          end

          status = filters[:status]
          rows = []
          rows.concat(pending_rows(filters)) if status == "all" || status == "pending"
          rows.concat(locked_rows(filters)) if status == "all" || status == "locked"
          rows.concat(failed_rows(filters)) if status == "all" || status == "failed"
          rows
        rescue StandardError => e
          Anomonitor.logger.warn("[Anomonitor] Sidekiq jobs browser error: #{e.message}")
          []
        end

        private

        def pending_rows(filters)
          queues = ::Sidekiq::Queue.all
          queues = queues.select { |q| q.name == filters[:queue] } if filters[:queue]
          rows = []
          queues.each do |queue|
            queue.each do |job|
              rows << row_from_job(job, status: "pending", queue: queue.name)
              break if rows.size >= PER_SET
            end
            break if rows.size >= PER_SET
          end
          rows
        end

        def locked_rows(filters)
          return [] unless defined?(::Sidekiq::Workers)

          rows = []
          ::Sidekiq::Workers.new.each do |_process_id, _thread_id, work|
            payload = work.is_a?(Hash) ? work : {}
            job = payload["payload"] || payload[:payload] || payload
            queue = payload["queue"] || payload[:queue] || job["queue"]
            next if filters[:queue] && queue.to_s != filters[:queue]

            rows << Row.new(
              source: source_key,
              id: job["jid"] || job[:jid],
              name: job["class"] || job[:class] || "Sidekiq::Job",
              status: "locked",
              queue: queue,
              tenant: nil,
              run_at: parse_time(payload["run_at"] || payload[:run_at] || job["enqueued_at"]),
              failed_at: nil,
              error: nil,
              tags: {}
            )
            break if rows.size >= PER_SET
          end
          rows
        rescue StandardError
          []
        end

        def failed_rows(filters)
          rows = []
          if defined?(::Sidekiq::RetrySet)
            ::Sidekiq::RetrySet.new.each do |job|
              next if filters[:queue] && job.queue.to_s != filters[:queue]

              rows << row_from_job(job, status: "failed", queue: job.queue, error: job["error_message"])
              break if rows.size >= PER_SET
            end
          end
          if defined?(::Sidekiq::DeadSet) && rows.size < PER_SET
            ::Sidekiq::DeadSet.new.each do |job|
              next if filters[:queue] && job.queue.to_s != filters[:queue]

              rows << row_from_job(job, status: "failed", queue: job.queue, error: job["error_message"])
              break if rows.size >= PER_SET
            end
          end
          rows
        end

        def row_from_job(job, status:, queue:, error: nil)
          klass =
            if job.respond_to?(:display_class)
              job.display_class
            elsif job.respond_to?(:klass)
              job.klass
            else
              job["class"]
            end
          jid = job.respond_to?(:jid) ? job.jid : job["jid"]
          at =
            if job.respond_to?(:enqueued_at) && job.enqueued_at
              parse_time(job.enqueued_at)
            elsif job["enqueued_at"]
              parse_time(job["enqueued_at"])
            elsif job.respond_to?(:created_at)
              parse_time(job.created_at)
            end

          err = error
          err ||= job["error_message"] if job.respond_to?(:[])

          Row.new(
            source: source_key,
            id: jid,
            name: klass.to_s,
            status: status,
            queue: queue,
            tenant: nil,
            run_at: at,
            failed_at: status == "failed" ? at : nil,
            error: truncate(err),
            tags: {}
          )
        end

        def parse_time(value)
          return nil if value.nil?
          return value if value.is_a?(Time) || value.is_a?(DateTime)
          return Time.at(value) if value.is_a?(Numeric)

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
