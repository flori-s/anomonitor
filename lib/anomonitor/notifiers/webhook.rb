# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module Anomonitor
  module Notifiers
    class Webhook
      def initialize(url: Anomonitor.config.webhook_url)
        @url = url
      end

      def deliver(anomaly)
        return false if @url.nil? || @url.to_s.strip.empty?

        payload = build_payload(anomaly)
        response = post_json(payload)
        success = response.is_a?(Net::HTTPSuccess)

        unless success
          Anomonitor.logger.warn(
            "[Anomonitor] Webhook failed: HTTP #{response&.code} #{response&.body}"
          )
        end

        success
      rescue StandardError => e
        Anomonitor.logger.warn("[Anomonitor] Webhook error: #{e.message}")
        false
      end

      private

      def build_payload(anomaly)
        {
          gem: "anomonitor",
          event: "anomaly.detected",
          severity: anomaly.severity,
          rule: anomaly.rule,
          source: anomaly.source,
          metric: anomaly.metric,
          value: anomaly.value,
          threshold: anomaly.threshold,
          sampled_at: anomaly.sampled_at&.iso8601,
          dashboard_url: "#{Anomonitor.config.dashboard_path}/anomalies/#{anomaly.id}",
          tags: anomaly.tags
        }
      end

      def post_json(payload)
        uri = URI.parse(@url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.open_timeout = 5
        http.read_timeout = 10

        request = Net::HTTP::Post.new(uri)
        request["Content-Type"] = "application/json"
        request["User-Agent"] = "anomonitor/#{Anomonitor::VERSION}"
        request.body = JSON.generate(payload)

        response = http.request(request)
        if response.is_a?(Net::HTTPServerError)
          sleep 0.5
          response = http.request(request)
        end
        response
      end
    end
  end
end
