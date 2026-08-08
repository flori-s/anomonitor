# frozen_string_literal: true

module Anomonitor
  module Notifiers
    class Composite
      def initialize(notifiers)
        @notifiers = Array(notifiers)
      end

      def deliver(anomaly, event: DETECTED)
        results = @notifiers.map do |notifier|
          notifier.deliver(anomaly, event: event)
        rescue StandardError => e
          Anomonitor.logger.warn("[Anomonitor] Notifier #{notifier.class} error: #{e.message}")
          false
        end
        results.any?
      end
    end
  end
end
