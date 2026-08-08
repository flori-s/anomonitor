# frozen_string_literal: true

module Anomonitor
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :exception
    layout "anomonitor/application"

    helper Anomonitor::Engine.helpers

    before_action :authenticate_anomonitor!

    private

    def authenticate_anomonitor!
      auth = Anomonitor.config.authenticate
      return if auth.nil?

      instance_exec(&auth)
    end
  end
end
