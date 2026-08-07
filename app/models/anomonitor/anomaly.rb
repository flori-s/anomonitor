# frozen_string_literal: true

module Anomonitor
  class Anomaly < ApplicationRecord
    self.table_name = "anomonitor_anomalies"

    validates :rule, :source, :metric, :value, :severity, :cooldown_key, presence: true

    scope :recent, -> { order(created_at: :desc) }
  end
end
