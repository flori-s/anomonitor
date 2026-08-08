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

      def deliver_digest(payload)
        results = @notifiers.map do |notifier|
          next false unless notifier.respond_to?(:deliver_digest)

          notifier.deliver_digest(payload)
        rescue StandardError => e
          Anomonitor.logger.warn("[Anomonitor] Digest notifier #{notifier.class} error: #{e.message}")
          false
        end
        results.any?
      end
    end
  end
end
