# frozen_string_literal: true

module Anomonitor
  class Anomaly < ApplicationRecord
    self.table_name = "anomonitor_anomalies"

    validates :rule, :source, :metric, :value, :severity, :cooldown_key, presence: true

    scope :recent, -> { order(created_at: :desc) }
    scope :open, -> { where(resolved_at: nil) }
    scope :resolved, -> { where.not(resolved_at: nil) }
    scope :webhook_failed, -> { where(webhook_status: "failed") }

    def open?
      resolved_at.nil?
    end

    def resolved?
      !open?
    end

    def webhook_failed?
      webhook_status.to_s == "failed"
    end

    def manual_resolve?
      tag_value("resolved_by").to_s == "manual"
    end

    def cleared_after_ack?
      tag_value("cleared_at").present?
    end

    def resolve!(by: "auto", notify: false)
      return self if resolved?

      merge_tags!("resolved_by" => by.to_s)
      update!(resolved_at: Time.current)
      if notify
        event = by.to_s == "manual" ? Notifiers::ACKED : Notifiers::RESOLVED
        Anomonitor.config.build_notifier.deliver(self, event: event)
      end
      self
    end

    def reopen!
      # Lift manual-ack silence so the next matching drift can notify again.
      # Keeps history as resolved unless it was still open.
      if open?
        merge_tags!("reopened_at" => Time.current.iso8601)
        save!
        return self
      end

      merge_tags!(
        "cleared_at" => Time.current.iso8601,
        "reopened_at" => Time.current.iso8601
      )
      save!
      self
    end

    def retry_webhook!
      delivered = Anomonitor.config.build_notifier.deliver(
        self,
        event: resolved? ? Notifiers::RESOLVED : Notifiers::DETECTED
      )
      update!(
        webhook_status: delivered ? "delivered" : "failed",
        webhook_delivered_at: delivered ? Time.current : webhook_delivered_at
      )
      delivered
    end

    def items_list
      list = tag_value("items_list")
      return Array(list) if list.is_a?(Array)

      items = tag_value("items")
      return [] if items.nil? || items.to_s.empty?

      items.to_s.split(",").map(&:strip)
    end

    def tag_value(key)
      t = tags
      return nil unless t.is_a?(Hash)

      t[key.to_s] || t[key.to_sym]
    end

    def merge_tags!(extra)
      current = tags.is_a?(Hash) ? tags.stringify_keys : {}
      extra = extra.stringify_keys
      extra.each do |k, v|
        if v.nil?
          current.delete(k)
        else
          current[k] = v
        end
      end
      self.tags = current
    end
  end
end
