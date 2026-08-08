# frozen_string_literal: true

module Anomonitor
  class AnomaliesController < ApplicationController
    before_action :set_anomaly, only: %i[show resolve reopen retry_webhook]

    def index
      @status_filter = params[:status].presence || "open"
      scope = Anomaly.recent
      scope =
        case @status_filter
        when "resolved" then scope.resolved
        when "all" then scope
        else scope.open
        end
      @anomalies = scope.limit(100)
    end

    def show
    end

    def resolve
      @anomaly.resolve!(by: "manual", notify: true)
      redirect_to anomaly_path(@anomaly), notice: "Anomaly resolved (silenced until drift clears)."
    end

    def reopen
      @anomaly.reopen!
      redirect_to anomaly_path(@anomaly), notice: "Alerts allowed again for this fingerprint."
    end

    def retry_webhook
      ok = @anomaly.retry_webhook!
      redirect_to anomaly_path(@anomaly),
                  notice: (ok ? "Webhook delivered." : "Webhook delivery failed again.")
    end

    private

    def set_anomaly
      @anomaly = Anomaly.find(params[:id])
    end
  end
end
