# frozen_string_literal: true

module Anomonitor
  module Collectors
    class Table < Base
      def initialize(source)
        @source = source
      end

      def collect
        klass = @source.model_class

        if tenant_column?(klass)
          collect_per_tenant(klass)
        else
          metrics_for(klass.all, nil)
        end
      rescue NameError => e
        log_skip("model #{@source.model} not found: #{e.message}")
        []
      rescue StandardError => e
        Anomonitor.logger.warn("[Anomonitor] Table collector (#{@source.name}) error: #{e.message}")
        []
      end

      private

      def tenant_column?(klass)
        col = @source.tenant
        col && klass.column_names.include?(col.to_s)
      end

      def collect_per_tenant(klass)
        column = @source.tenant
        points = []
        klass.distinct.pluck(column).compact.each do |tenant|
          points.concat(metrics_for(klass.where(column => tenant), tenant))
        end
        points
      end

      def metrics_for(scope, tenant)
        tags = { table: @source.name.to_s }
        tags[:tenant] = tenant if tenant

        if @source.delayed_job_style?
          delayed_job_metrics(scope, tags)
        else
          status_metrics(scope, tags)
        end
      end

      def status_metrics(scope, tags)
        points = []
        active_scope = scope
        if @source.status && @source.active
          active_scope = scope.where(@source.status => @source.active)
        end

        points << point(source: source_name, metric: "active", value: active_scope.count, tags: tags)
        points << point(source: source_name, metric: "queue_depth", value: active_scope.count, tags: tags)

        timestamp = @source.timestamp || :created_at
        window = spike_window
        if scope.klass.column_names.include?(timestamp.to_s)
          recent = scope.where(timestamp => window.ago..Time.current).count
          previous = scope.where(timestamp => (window * 2).ago...window.ago).count
          points << point(
            source: source_name,
            metric: "growth_rate",
            value: recent,
            tags: tags.merge(previous: previous)
          )
        end

        points
      end

      def delayed_job_metrics(scope, tags)
        now = Time.current
        cols = scope.klass.column_names

        pending = scope.where(failed_at: nil).where("run_at <= ?", now)
        if cols.include?("locked_by")
          pending = pending.where(locked_by: nil)
        elsif cols.include?("locked_at")
          pending = pending.where(locked_at: nil)
        end

        failed = scope.where.not(failed_at: nil).count
        locked =
          if cols.include?("locked_at")
            scope.where.not(locked_at: nil).where(failed_at: nil).count
          else
            0
          end

        [
          point(source: source_name, metric: "queue_depth", value: pending.count, tags: tags),
          point(source: source_name, metric: "failed", value: failed, tags: tags),
          point(source: source_name, metric: "locked", value: locked, tags: tags),
          point(source: source_name, metric: "total", value: scope.count, tags: tags)
        ]
      end

      def source_name
        "table:#{@source.name}"
      end

      def spike_window
        rule = Anomonitor.config.alerts.find(&:spike?)
        seconds = rule ? rule.window_seconds : 300
        seconds.to_i.seconds
      end
    end
  end
end
