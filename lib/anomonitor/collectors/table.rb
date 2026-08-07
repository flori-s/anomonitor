# frozen_string_literal: true

module Anomonitor
  module Collectors
    class Table < Base
      def initialize(source)
        @source = source
      end

      def collect
        klass = @source.model_class
        points = []

        active_scope = klass.all
        if @source.status && @source.active
          active_scope = active_scope.where(@source.status => @source.active)
        end

        points << point(
          source: "table:#{@source.name}",
          metric: "active",
          value: active_scope.count,
          tags: { table: @source.name.to_s }
        )

        points << point(
          source: "table:#{@source.name}",
          metric: "queue_depth",
          value: active_scope.count,
          tags: { table: @source.name.to_s }
        )

        timestamp = @source.timestamp || :created_at
        window = spike_window
        if klass.column_names.include?(timestamp.to_s)
          recent = klass.where(timestamp => window.ago..Time.current).count
          previous = klass.where(timestamp => (window * 2).ago...window.ago).count

          points << point(
            source: "table:#{@source.name}",
            metric: "growth_rate",
            value: recent,
            tags: { table: @source.name.to_s, previous: previous }
          )
        end

        points
      rescue NameError => e
        log_skip("model #{@source.model} not found: #{e.message}")
        []
      rescue StandardError => e
        Anomonitor.logger.warn("[Anomonitor] Table collector (#{@source.name}) error: #{e.message}")
        []
      end

      private

      def spike_window
        rule = Anomonitor.config.alerts.find(&:spike?)
        seconds = rule ? rule.window_seconds : 300
        seconds.to_i.seconds
      end
    end
  end
end
