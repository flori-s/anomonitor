# frozen_string_literal: true

module Anomonitor
  class Anomaly < ApplicationRecord
    self.table_name = "anomonitor_anomalies"

    validates :rule, :source, :metric, :value, :severity, :cooldown_key, presence: true

    scope :recent, -> { order(created_at: :desc) }
    scope :open, -> { where(resolved_at: nil) }
    scope :resolved, -> { where.not(resolved_at: nil) }

    def open?
      resolved_at.nil?
    end

    def resolved?
      !open?
    end
  end
end
