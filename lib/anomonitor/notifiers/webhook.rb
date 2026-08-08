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

      def deliver(anomaly, event: DETECTED)
        return false if @url.nil? || @url.to_s.strip.empty?

        payload = build_payload(anomaly, event.to_s)
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

      def build_payload(anomaly, event)
        if slack_incoming_webhook?
          { text: slack_text(anomaly, event) }
        else
          Notifiers.payload(anomaly, event: event)
        end
      end

      def slack_incoming_webhook?
        @url.to_s.include?("hooks.slack.com")
      end

      def slack_text(anomaly, event)
        threshold = anomaly.threshold.nil? ? "n/a" : anomaly.threshold
        dashboard = Anomonitor.config.anomaly_dashboard_url(anomaly.id)
        tags = anomaly.tags.is_a?(Hash) ? anomaly.tags : {}
        tenant = tags["tenant"] || tags[:tenant]
        items = tags["items"] || tags[:items]
        resolved = event == RESOLVED

        parts = ["*Anomonitor*"]
        parts << (resolved ? "resolved" : anomaly.severity.to_s)
        parts << "tenant `#{tenant}`" if tenant && !tenant.to_s.empty?
        parts << "— #{anomaly.rule} on #{anomaly.source}/#{anomaly.metric}:"
        parts << "#{anomaly.value} (threshold #{threshold})"
        parts << "items: #{items}" if items && !items.to_s.empty?
        parts << "<#{dashboard}>"
        parts.join(" ")
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
