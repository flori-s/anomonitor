# frozen_string_literal: true

module Anomonitor
  class AnomaliesController < ApplicationController
    def index
      @anomalies = Anomaly.recent.limit(100)
    end

    def show
      @anomaly = Anomaly.find(params[:id])
    end
  end
end
