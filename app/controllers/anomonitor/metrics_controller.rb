# frozen_string_literal: true

module Anomonitor
  class MetricsController < ApplicationController
    def index
      @metrics = MetricSample.recent(24).order(sampled_at: :desc).limit(200)
    end
  end
end
