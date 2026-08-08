# frozen_string_literal: true

module Anomonitor
  class AnomaliesController < ApplicationController
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
      @anomaly = Anomaly.find(params[:id])
    end
  end
end
