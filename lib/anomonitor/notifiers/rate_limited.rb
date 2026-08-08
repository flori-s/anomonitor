# frozen_string_literal: true

module Anomonitor
  module Notifiers
    class RateLimited
      def initialize(notifier, limit_per_minute:)
        @notifier = notifier
        @limit = limit_per_minute.to_i
        @timestamps = []
        @mutex = Mutex.new
      end

      def deliver(anomaly, event: DETECTED)
        return false unless allow?

        @notifier.deliver(anomaly, event: event)
      end

      def deliver_digest(payload)
        return false unless allow?
        return @notifier.deliver_digest(payload) if @notifier.respond_to?(:deliver_digest)

        false
      end

      private

      def allow?
        return true if @limit <= 0

        @mutex.synchronize do
          cutoff = Time.current - 60
          @timestamps.reject! { |t| t < cutoff }
          if @timestamps.size >= @limit
            Anomonitor.logger.warn("[Anomonitor] Notifier rate limit reached (#{@limit}/min)")
            return false
          end
          @timestamps << Time.current
          true
        end
      end
    end
  end
end
