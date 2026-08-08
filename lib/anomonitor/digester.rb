# frozen_string_literal: true

module Anomonitor
  # Batches anomaly.detected notifications into a single anomaly.digest payload.
  class Digester
    def self.record(anomaly)
      new.record(anomaly)
    end

    def self.flush_if_due!(notifier: nil)
      new(notifier: notifier).flush_if_due!
    end

    def initialize(notifier: nil)
      @notifier = notifier || Anomonitor.config.build_notifier
    end

    def record(anomaly)
      anomaly.update!(webhook_status: "queued")
      true
    rescue StandardError => e
      Anomonitor.logger.warn("[Anomonitor] Digester record failed: #{e.message}")
      false
    end

    def flush_if_due!
      interval = Anomonitor.config.digest_interval.to_i
      return 0 if interval <= 0

      last = Anomonitor.config.digest_last_flushed_at
      return 0 if last && Time.current - last < interval

      flush!
    end

    def flush!
      queued = Anomonitor::Anomaly.where(webhook_status: "queued").order(:created_at).limit(100).to_a
      return 0 if queued.empty?

      path = Anomonitor.config.dashboard_path.to_s.sub(%r{/+\z}, "")
      base = Anomonitor.config.dashboard_base_url.to_s.strip.sub(%r{/+\z}, "")
      dash = base.empty? ? "#{path}/anomalies" : "#{base}#{path}/anomalies"

      payload = {
        gem: "anomonitor",
        event: Notifiers::DIGEST,
        count: queued.size,
        dashboard_url: dash,
        anomalies: queued.map { |a| Notifiers.payload(a, event: Notifiers::DETECTED) }
      }

      delivered = deliver_digest(payload)
      queued.each do |anomaly|
        anomaly.update!(
          webhook_status: delivered ? "delivered" : "failed",
          webhook_delivered_at: delivered ? Time.current : nil
        )
      end
      Anomonitor.config.digest_last_flushed_at = Time.current
      queued.size
    rescue StandardError => e
      Anomonitor.logger.warn("[Anomonitor] Digester flush failed: #{e.message}")
      0
    end

    private

    def deliver_digest(payload)
      if @notifier.respond_to?(:deliver_digest)
        @notifier.deliver_digest(payload)
      else
        false
      end
    rescue StandardError => e
      Anomonitor.logger.warn("[Anomonitor] Digest deliver error: #{e.message}")
      false
    end
  end
end
