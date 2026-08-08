# frozen_string_literal: true

module Anomonitor
  class MetricsController < ApplicationController
    def index
      @metrics = MetricSample.recent(24).order(sampled_at: :desc).limit(200)
    end

    def export_json
      render json: MetricsExport.json_payload
    end

    def export_prometheus
      render plain: MetricsExport.prometheus_text,
             content_type: "text/plain; version=0.0.4; charset=utf-8"
    end
  end
end
