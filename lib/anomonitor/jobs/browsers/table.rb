# frozen_string_literal: true

module Anomonitor
  module Jobs
    module Browsers
      class Table
        LIMIT = 100

        def initialize(source)
          @source = source
        end

        def source_key
          "table:#{@source.name}"
        end

        def fetch(filters)
          klass = @source.model_class
          scope = klass.all
          scope = scope.where(@source.tenant => filters[:tenant]) if filters[:tenant] && tenant_column?(klass)

          if @source.delayed_job_style?
            delayed_job_rows(scope, filters)
          else
            status_rows(scope, filters)
          end
        rescue NameError => e
          Anomonitor.logger.warn("[Anomonitor] Jobs browser skipped #{source_key}: #{e.message}")
          []
        rescue StandardError => e
          Anomonitor.logger.warn("[Anomonitor] Table jobs browser (#{@source.name}) error: #{e.message}")
          []
        end

        private

        def tenant_column?(klass)
          col = @source.tenant
          col && klass.column_names.include?(col.to_s)
        end

        def delayed_job_rows(scope, filters)
          cols = scope.klass.column_names
          scope = apply_delayed_status(scope, filters[:status], cols)
          if filters[:queue] && cols.include?("queue")
            scope = scope.where(queue: filters[:queue])
          end
          order_col = %w[failed_at run_at created_at updated_at].find { |c| cols.include?(c) }
          scope = scope.order(order_col => :desc) if order_col
          scope.limit(LIMIT).map { |record| delayed_row(record, cols) }
        end

        def apply_delayed_status(scope, status, cols)
          case status
          when "pending"
            scope = scope.where(failed_at: nil) if cols.include?("failed_at")
            if cols.include?("locked_by")
              scope = scope.where(locked_by: nil)
            elsif cols.include?("locked_at")
              scope = scope.where(locked_at: nil)
            end
            scope = scope.where("run_at <= ?", Time.current) if cols.include?("run_at")
            scope
          when "failed"
            cols.include?("failed_at") ? scope.where.not(failed_at: nil) : scope.none
          when "locked"
            return scope.none unless cols.include?("locked_at")

            scope = scope.where.not(locked_at: nil)
            scope = scope.where(failed_at: nil) if cols.include?("failed_at")
            scope
          else
            scope
          end
        end

        def delayed_row(record, cols)
          tenant = cols.include?(@source.tenant.to_s) ? record.public_send(@source.tenant) : nil
          error = cols.include?("last_error") ? record.public_send(:last_error) : nil
          error = error.to_s.lines.first&.strip if error

          Row.new(
            source: source_key,
            id: record.id,
            name: record_name(record),
            status: delayed_status(record, cols),
            queue: cols.include?("queue") ? record.queue : nil,
            tenant: tenant,
            run_at: cols.include?("run_at") ? record.run_at : nil,
            failed_at: cols.include?("failed_at") ? record.failed_at : nil,
            error: truncate(error),
            tags: { table: @source.name.to_s }.tap { |t| t[:tenant] = tenant if tenant }
          )
        end

        def delayed_status(record, cols)
          return "failed" if cols.include?("failed_at") && record.failed_at
          return "locked" if cols.include?("locked_at") && record.locked_at

          "pending"
        end

        def status_rows(scope, filters)
          cols = scope.klass.column_names
          status_col = @source.status
          if status_col && cols.include?(status_col.to_s)
            scope = apply_status_filter(scope, filters[:status], status_col)
          elsif filters[:status] != "all"
            return []
          end

          if filters[:queue] && cols.include?("queue")
            scope = scope.where(queue: filters[:queue])
          end

          order_col = %w[updated_at created_at].find { |c| cols.include?(c) }
          scope = scope.order(order_col => :desc) if order_col
          scope.limit(LIMIT).map { |record| status_row(record, cols, status_col) }
        end

        def apply_status_filter(scope, status, status_col)
          active = Array(@source.active).map(&:to_s)
          case status
          when "pending", "locked"
            # status-style tables: active statuses map to pending; no distinct locked
            return scope.none if status == "locked"
            return scope.where(status_col => active) if active.any?

            scope
          when "failed"
            failed = infer_failed_statuses(scope.klass, status_col, active)
            failed.any? ? scope.where(status_col => failed) : scope.none
          else
            scope
          end
        end

        def infer_failed_statuses(klass, status_col, active)
          known = %w[failed error dead]
          values = klass.distinct.limit(50).pluck(status_col).compact.map(&:to_s)
          values.select { |v| known.include?(v.downcase) || (active.any? && !active.include?(v)) }
                .select { |v| %w[failed error dead].include?(v.downcase) }
        end

        def status_row(record, cols, status_col)
          raw_status = status_col && cols.include?(status_col.to_s) ? record.public_send(status_col).to_s : "pending"
          active = Array(@source.active).map(&:to_s)
          mapped =
            if %w[failed error dead].include?(raw_status.downcase)
              "failed"
            elsif active.include?(raw_status)
              "pending"
            else
              raw_status.presence || "pending"
            end

          tenant = @source.tenant && cols.include?(@source.tenant.to_s) ? record.public_send(@source.tenant) : nil
          run_at =
            if @source.timestamp && cols.include?(@source.timestamp.to_s)
              record.public_send(@source.timestamp)
            elsif cols.include?("created_at")
              record.created_at
            end

          Row.new(
            source: source_key,
            id: record.id,
            name: record_name(record),
            status: mapped,
            queue: cols.include?("queue") ? record.queue : nil,
            tenant: tenant,
            run_at: run_at,
            failed_at: mapped == "failed" ? run_at : nil,
            error: nil,
            tags: { table: @source.name.to_s, status: raw_status }.tap { |t| t[:tenant] = tenant if tenant }
          )
        end

        def record_name(record)
          if record.respond_to?(:name) && record.name.present?
            record.name.to_s
          elsif record.respond_to?(:handler) && record.handler.present?
            record.handler.to_s.lines.first.to_s.strip[0, 80]
          elsif record.respond_to?(:job_class) && record.job_class.present?
            record.job_class.to_s
          else
            @source.model.to_s
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
