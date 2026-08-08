# frozen_string_literal: true

module Anomonitor
  module Notifiers
    class Callable
      def initialize(callable)
        @callable = callable
      end

      def deliver(anomaly, event: DETECTED)
        result =
          if accepts_event_kw?
            @callable.call(anomaly, event: event.to_s)
          else
            @callable.call(anomaly)
          end

        normalize_result(result)
      rescue StandardError => e
        Anomonitor.logger.warn("[Anomonitor] Custom notifier error: #{e.message}")
        false
      end

      private

      def accepts_event_kw?
        params = @callable.parameters
        params.any? { |type, name| name == :event && %i[key keyreq keyrest].include?(type) } ||
          params.any? { |type, _| type == :keyrest }
      rescue StandardError
        true
      end

      def normalize_result(result)
        case result
        when true, false then result
        when Hash then result[:accepted] == true || result["accepted"] == true
        else
          !result.nil?
        end
      end
    end
  end
end
