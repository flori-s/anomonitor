# frozen_string_literal: true

module Anomonitor
  module Collectors
    class Base
      def collect
        raise NotImplementedError
      end

      protected

      def available?
        true
      end

      def point(source:, metric:, value:, tags: {})
        MetricPoint.new(source: source, metric: metric, value: value, tags: tags)
      end

      def log_skip(reason)
        Anomonitor.logger.debug("[Anomonitor] Skipping #{self.class.name}: #{reason}")
      end
    end
  end
end
