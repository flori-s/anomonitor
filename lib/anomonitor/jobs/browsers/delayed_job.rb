# frozen_string_literal: true

module Anomonitor
  module Jobs
    module Browsers
      class DelayedJob
        PER_TENANT = 50

        def source_key
          "delayed_job"
        end

        def fetch(filters)
          unless defined?(::Delayed::Job)
            Anomonitor.logger.warn("[Anomonitor] Jobs browser skipped delayed_job: Delayed::Job not loaded")
            return []
          end

          if Tenancy.multi_tenant?
            fetch_per_tenant(filters)
          else
            fetch_scope(::Delayed::Job, filters, nil)
          end
        rescue StandardError => e
          Anomonitor.logger.warn("[Anomonitor] Delayed Job browser error: #{e.message}")
          []
        end

        private

        def fetch_per_tenant(filters)
          rows = []
          tenants = Tenancy.tenant_names
          tenants = tenants.select { |t| t == filters[:tenant] } if filters[:tenant]
          tenants.each do |tenant|
            Tenancy.switch(tenant) do
              rows.concat(fetch_scope(::Delayed::Job, filters, tenant))
            end
          rescue StandardError => e
            Anomonitor.logger.warn("[Anomonitor] Delayed Job browser (#{tenant}) error: #{e.message}")
          end
          rows
        end

        def fetch_scope(klass, filters, tenant)
          scope = apply_status(klass.all, filters[:status])
          if filters[:queue] && klass.column_names.include?("queue")
            scope = scope.where(queue: filters[:queue])
          end
          scope = scope.order(Arel.sql("COALESCE(failed_at, run_at, created_at) DESC"))
          scope.limit(PER_TENANT).map { |job| row_for(job, tenant) }
        rescue StandardError
          # SQLite / adapters without Arel.sql coalesce ordering
          scope = apply_status(klass.all, filters[:status])
          if filters[:queue] && klass.column_names.include?("queue")
            scope = scope.where(queue: filters[:queue])
          end
          scope.limit(PER_TENANT).map { |job| row_for(job, tenant) }
        end

        def apply_status(scope, status)
          case status
          when "pending"
            scope = scope.where(failed_at: nil).where(locked_at: nil)
            if scope.klass.column_names.include?("run_at")
              scope = scope.where("run_at <= ?", Time.current)
            end
            scope
          when "failed"
            scope.where.not(failed_at: nil)
          when "locked"
            scope.where.not(locked_at: nil).where(failed_at: nil)
          else
            scope
          end
        end

        def row_for(job, tenant)
          name =
            if job.respond_to?(:name) && job.name.present?
              job.name
            elsif job.respond_to?(:handler)
              handler_class(job.handler)
            else
              "Delayed::Job"
            end

          error = nil
          full_error = nil
          if job.respond_to?(:last_error) && job.last_error
            full_error = job.last_error.to_s
            error = full_error.lines.first&.strip
          end
          handler = job.respond_to?(:handler) ? job.handler.to_s : nil

          Row.new(
            source: source_key,
            id: job.id,
            name: name,
            status: status_for(job),
            queue: job.respond_to?(:queue) ? job.queue : nil,
            tenant: tenant,
            run_at: job.respond_to?(:run_at) ? job.run_at : nil,
            failed_at: job.respond_to?(:failed_at) ? job.failed_at : nil,
            error: truncate(error),
            tags: tenant ? { tenant: tenant } : {},
            detail: {
              "handler" => truncate(handler, 800),
              "error" => truncate(full_error, 1000),
              "attempts" => (job.respond_to?(:attempts) ? job.attempts : nil)
            }.compact
          )
        end

        def status_for(job)
          return "failed" if job.respond_to?(:failed_at) && job.failed_at
          return "locked" if job.respond_to?(:locked_at) && job.locked_at

          "pending"
        end

        def handler_class(handler)
          return "Delayed::Job" if handler.blank?

          if handler =~ /!ruby\/object:(\S+)/
            Regexp.last_match(1)
          elsif handler =~ /job_class:\s*(\S+)/
            Regexp.last_match(1)
          else
            handler.to_s.lines.first.to_s.strip[0, 80]
          end
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
