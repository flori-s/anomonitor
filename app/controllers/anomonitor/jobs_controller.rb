# frozen_string_literal: true

module Anomonitor
  class JobsController < ApplicationController
    def index
      @status = Poller.instance.status.merge(poll_mode: Anomonitor.config.poll_mode)
      @filters = {
        source: params[:source].presence,
        status: params[:status].presence || "all",
        tenant: params[:tenant].presence,
        queue: params[:queue].presence,
        q: params[:q].presence
      }
      @sources = Jobs::Browser.enabled_sources
      @status_options = Jobs::Browser.status_options(@filters[:source])
      @filters[:status] = "all" unless @status_options.include?(@filters[:status])
      @health = Jobs::Health.cards(sources: @sources, status: @status)
      @jobs = Jobs::Browser.fetch(@filters)
    end
  end
end
