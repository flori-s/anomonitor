# frozen_string_literal: true

module Anomonitor
  class Detector
    def initialize(notifier: Notifiers::Webhook.new)
      @notifier = notifier
    end

    def evaluate(points)
      @active_sticky_keys = []
      @observed_sticky_bases = []
      anomalies = []

      unless points.empty?
        Anomonitor.config.alerts.each do |rule|
          points.each do |point|
            next unless metric_matches?(rule, point)

            anomaly = detect(rule, point)
            anomalies << anomaly if anomaly
          end
        end
      end

      resolve_sticky_anomalies(@active_sticky_keys, @observed_sticky_bases)
      anomalies
    end

    private

    def metric_matches?(rule, point)
      point.metric.to_s == rule.metric.to_s ||
        (rule.spike? && %w[growth_rate queue_depth active].include?(point.metric.to_s) && rule.metric.to_s == "growth_spike") ||
        (rule.threshold? && point.metric.to_s == rule.metric.to_s)
    end

    def detect(rule, point)
      if rule.threshold? && point.metric.to_s == rule.metric.to_s
        note_sticky_observation(point) if point.sticky?
        return nil unless point.value > rule.max

        create_anomaly(rule, point, threshold: rule.max, reason: "threshold")
      elsif rule.spike?
        detect_spike(rule, point)
      end
    end

    def detect_spike(rule, point)
      previous = previous_value(point)
      return nil if previous.nil? || previous <= 0

      ratio = point.value / previous.to_f
      return nil unless ratio >= rule.multiplier

      create_anomaly(
        rule,
        point,
        threshold: previous * rule.multiplier,
        reason: "growth_spike",
        extra: { previous: previous, ratio: ratio.round(2) }
      )
    end

    def previous_value(point)
      tags_previous = point.tags[:previous] || point.tags["previous"]
      return tags_previous.to_f if tags_previous

      window = spike_window_seconds
      prior = Anomonitor::MetricSample
              .where(source: point.source, metric: point.metric)
              .where("sampled_at >= ? AND sampled_at < ?", (window * 2).seconds.ago, window.seconds.ago)
              .order(sampled_at: :desc)
              .limit(5)

      if point.tags[:queue] || point.tags["queue"]
        queue = point.tags[:queue] || point.tags["queue"]
        prior = prior.select { |s| (s.tags || {})["queue"] == queue || (s.tags || {})[:queue] == queue }
      end

      if point.tags[:tenant] || point.tags["tenant"]
        tenant = point.tags[:tenant] || point.tags["tenant"]
        prior = prior.select { |s| (s.tags || {})["tenant"] == tenant || (s.tags || {})[:tenant] == tenant }
      end

      values = prior.map(&:value)
      return nil if values.empty?

      values.sum / values.size.to_f
    rescue StandardError
      nil
    end

    def spike_window_seconds
      rule = Anomonitor.config.alerts.find(&:spike?)
      rule ? rule.window_seconds.to_i : 300
    end

    def create_anomaly(rule, point, threshold:, reason:, extra: {})
      key = "#{reason}:#{point.cooldown_key}"
      @active_sticky_keys << key if point.sticky?

      return nil if cooling_down?(key, point)

      anomaly = Anomonitor::Anomaly.create!(
        rule: reason,
        source: point.source,
        metric: point.metric,
        value: point.value,
        threshold: threshold,
        severity: rule.severity,
        cooldown_key: key,
        tags: point.tags.merge(extra),
        sampled_at: point.sampled_at,
        webhook_status: "pending",
        resolved_at: nil
      )

      delivered = @notifier.deliver(anomaly)
      anomaly.update!(
        webhook_status: delivered ? "delivered" : "failed",
        webhook_delivered_at: delivered ? Time.current : nil
      )
      anomaly
    rescue StandardError => e
      Anomonitor.logger.warn("[Anomonitor] Failed to record anomaly: #{e.message}")
      nil
    end

    def cooling_down?(key, point = nil)
      if point&.sticky?
        Anomonitor::Anomaly.where(cooldown_key: key, resolved_at: nil).exists?
      else
        cooldown = Anomonitor.config.cooldown.to_i
        Anomonitor::Anomaly
          .where(cooldown_key: key)
          .where("created_at >= ?", cooldown.seconds.ago)
          .exists?
      end
    end

    def note_sticky_observation(point)
      @observed_sticky_bases << sticky_base(point)
    end

    def sticky_base(point)
      tenant = point.tags[:tenant] || point.tags["tenant"]
      [point.source, point.metric, tenant].compact.join(":")
    end

    def anomaly_sticky_base(anomaly)
      tags = anomaly.tags.is_a?(Hash) ? anomaly.tags : {}
      tenant = tags["tenant"] || tags[:tenant]
      [anomaly.source, anomaly.metric, tenant].compact.join(":")
    end

    # Resolve open schema-drift alerts only when that tenant/metric was observed this tick
    # and the fingerprint is no longer active (cleared or items changed).
    def resolve_sticky_anomalies(active_keys, observed_bases)
      return if observed_bases.empty?

      bases = observed_bases.uniq
      Anomonitor::Anomaly.where(source: "schema_drift", resolved_at: nil).find_each do |anomaly|
        next if active_keys.include?(anomaly.cooldown_key)
        next unless bases.include?(anomaly_sticky_base(anomaly))

        anomaly.update!(resolved_at: Time.current)
        @notifier.deliver(anomaly, event: Notifiers::Webhook::RESOLVED)
      end
    rescue StandardError => e
      Anomonitor.logger.warn("[Anomonitor] Failed to resolve sticky anomalies: #{e.message}")
    end
  end
end
