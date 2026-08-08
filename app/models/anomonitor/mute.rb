# frozen_string_literal: true

module Anomonitor
  class Mute < ApplicationRecord
    self.table_name = "anomonitor_mutes"

    validates :muted_until, presence: true

    scope :active, -> { where("muted_until > ?", Time.current) }
    scope :recent, -> { order(muted_until: :desc) }

    def active?
      muted_until > Time.current
    end

    def matches?(anomaly_or_attrs)
      attrs =
        if anomaly_or_attrs.respond_to?(:metric)
          {
            metric: anomaly_or_attrs.metric,
            rule: anomaly_or_attrs.rule,
            source: anomaly_or_attrs.source,
            tenant: tenant_from(anomaly_or_attrs)
          }
        else
          anomaly_or_attrs
        end

      return false if metric.present? && metric.to_s != attrs[:metric].to_s
      return false if rule.present? && rule.to_s != attrs[:rule].to_s
      return false if source.present? && source.to_s != attrs[:source].to_s
      return false if tenant.present? && tenant.to_s != attrs[:tenant].to_s

      true
    end

    def self.muted?(anomaly_or_attrs)
      active.any? { |m| m.matches?(anomaly_or_attrs) }
    rescue StandardError
      false
    end

    def self.prune_expired!
      where("muted_until <= ?", Time.current).delete_all
    end

    private

    def tenant_from(anomaly)
      tags = anomaly.tags
      return nil unless tags.is_a?(Hash)

      tags["tenant"] || tags[:tenant]
    end
  end
end
